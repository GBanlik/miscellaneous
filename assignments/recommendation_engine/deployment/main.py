from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

from typing import List, Tuple

from model import predict, get_product_data

app = FastAPI()

class PredictionOut(BaseModel):
    user_id: str
    recommended_products: List[str]
    known_products: List[str]

class PredictionIn(BaseModel):
    user_id: str


class ProductOut(BaseModel):
    product_code: str
    bravo_major_name: str
    bravo_minor_name: str
    bravo_sub_fran_name: str
    bravo_fran_name: str
    bravo_ww_fran_name: str

class ProductIn(BaseModel):
    product_id: str

@app.get("/")
async def model_info():
    return {
        'model_version': 'v1.01',
        'last_update': '2020-12-05'
    }


@app.post("/predict", response_model = PredictionOut, status_code = 200)
async def get_prediction(payload: PredictionIn):
    user_id = payload.user_id

    predictions, interactions = predict(user_id)

    if predictions is None or len(predictions) == 0:
        raise HTTPException(status_code=400, detail="Unexpected error.")

    response = {"user_id": user_id,
                "recommended_products": predictions,
                "known_products": interactions}

    return response


@app.post("/product", response_model = ProductOut, status_code = 200)
async def get_product(payload: ProductIn):
    product_id = payload.product_id
    product_data = get_product_data(product_id)
    
    if product_data is None or len(product_data) == 0:
        raise HTTPException(status_code=400, detail="Unexpected error.")

    response = {
        'product_code': product_data.get('product_code')[0],
        'bravo_major_name': product_data.get('bravo_major_name')[0],
        'bravo_minor_name': product_data.get('bravo_minor_name')[0],
        'bravo_sub_fran_name': product_data.get('bravo_sub_fran_name')[0],
        'bravo_fran_name': product_data.get('bravo_fran_name')[0],
        'bravo_ww_fran_name': product_data.get('bravo_ww_fran_name')[0]
    }

    return response
