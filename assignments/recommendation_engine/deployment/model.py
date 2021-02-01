import logging
import pickle5 as pickle

from pathlib import Path
from typing import List, Tuple, Dict

import pandas as pd
import numpy as np

from lightfm import LightFM
from lightfm.data import Dataset

BASE_DIR: str = Path(__file__).resolve(strict=True).parent
MODEL_FILE_NAME: str = './model/hybrid_model.pickle'
DATA_FILE_NAME: str = './model/base_data.csv'
PRODUCTS_FILE_NAME: str = './model/product_master.csv'

logger = logging.getLogger("api")

def predict(user_id: int) -> str:
    model_file = Path(BASE_DIR).joinpath(MODEL_FILE_NAME)
    data_file = Path(BASE_DIR).joinpath(DATA_FILE_NAME)
    
    if not model_file.exists():
        return None

    if not data_file.exists():
        return None

    model: LightFM = pickle.load(open(model_file, "rb" )) 
    data: pd.DataFrame = pd.read_csv(data_file)

    dataset = Dataset()

    dataset.fit((cac for cac in data.cac.unique())
                ,(product for product in data.product_code.unique())
               )

    features =  ['product_code', 'country_code', 'cost_bin']

    for product_feature in features:
        dataset.fit_partial(users= (cac for cac in data.cac.unique())
                        , items= (product for product in data.product_code.unique())
                        , item_features= (feature for feature in data[product_feature].unique())
                    )

    item_features = dataset.build_item_features(((getattr(row, 'product_code'), [getattr(row, product_feature) for product_feature in features if product_feature != 'product_code']) \
            for row in data[features].itertuples()))

    predicted_products: List[str] = sample_recommendation(model= model, dataset= dataset, raw_data= data, item_features=item_features, user_ids= user_id)

    return predicted_products


def sample_recommendation(model: LightFM, dataset: pd.DataFrame, raw_data: pd.DataFrame, item_features, user_ids, recommendations_num: int = 10) -> Tuple[List[str], List[str]]:
   
   for user_id in user_ids:
        # Retrieve the item's IDs
        items_map = [item_id for item_id in dataset.mapping()[2].values()]
        # Retrieve the product_code for each item ID
        items_names = [item_id for item_id in dataset.mapping()[2].keys()]
        # Construct a dataframe with product_codes and item ID as index
        items = pd.DataFrame(items_names, index = items_map)
        items.columns = ['product_code']

        # Retrieve the known items
        known_items = raw_data[raw_data.cac == 'cac_' + str(user_id)]['product_code'][: 5].values
        known_item_ids = items[items['product_code'].isin(known_items)].index.tolist()

        # Predict items
        scores = model.predict(user_ids, np.arange(recommendations_num) ,item_features= item_features)
        i_idx = [x for x in np.argsort(-scores)]

        # Remove known items
        i_idx = [x for x in i_idx if x not in known_item_ids]
        top_items = items[~items['product_code'].isin(known_items)].loc[i_idx]

        return top_items['product_code'].values.tolist(), known_items.tolist()

def get_product_data(product_id: str) -> Dict[str, str]:
    data_file = Path(BASE_DIR).joinpath(PRODUCTS_FILE_NAME)
    
    if not data_file.exists():
        return None

    data: pd.DataFrame = pd.read_csv(data_file)
    product_name: str = 'product_code_' + product_id
    
    try:
        return data[data['product_code'] == product_name].to_dict()
    except Exception as e:
        return None

