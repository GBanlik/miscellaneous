USE AdventureWorks;
go

/*

	Leadership Views

*/

create or alter view Auction.ProductSale as

select
	p1.ProductID
	,p1.Name ProductName
	,coalesce(psc1.Name, 'None') ProductSubCategory
	,p1.ListPrice
	,as1.AuctionSaleID
	,as1.SaleValue 
	,iif(as1.SaleValue < 0.9 * p1.ListPrice, 1, 0) SaleBelowThreshold
	,iif(as1.SaleValue < 0.9 * p1.ListPrice, 0.9 * p1.ListPrice - as1.SaleValue, 0.0) DiscountOnThresholdValue
	,iif(as1.SaleValue < 0.9 * p1.ListPrice, (0.9 * p1.ListPrice - as1.SaleValue) / (0.9 * p1.ListPrice), 0.0) DiscountOnThresholdPercent
	,iif(as1.SaleValue < p1.ListPrice, (p1.ListPrice - as1.SaleValue) / (p1.ListPrice), 0.0) DiscountPercent
from
	Auction.Sale as1
inner join
	Auction.Product ap1
on
	as1.AuctionProductID = ap1.AuctionProductID
left join
	Production.Product p1
on
	ap1.ProductID = p1.ProductID
left join
	Production.ProductSubcategory psc1
on
	p1.ProductSubcategoryID = psc1.ProductSubcategoryID
;
go

/*
	View Auction.ProductSaleAnalysis

*/

create or alter view Auction.ProductSaleAnalysis as

select
	coalesce(psc1.Name, 'None') ProductSubCategory
	,count(as1.AuctionSaleID) SalesNum
	,sum(as1.SaleValue) SalesValue
	,sum(iif(as1.SaleValue < 0.9 * p1.ListPrice, 1, 0)) NumSalesBelowThreshold
	,sum(iif(as1.SaleValue < 0.9 * p1.ListPrice, as1.SaleValue, 0)) TotalSalesBelowThreshold
	,sum(iif(as1.SaleValue < 0.9 * p1.ListPrice, 0.9 * p1.ListPrice - as1.SaleValue, 0.0)) DiscountOnThresholdValue
	,avg(iif(as1.SaleValue < 0.9 * p1.ListPrice, (0.9 * p1.ListPrice - as1.SaleValue) / (0.9 * p1.ListPrice), 0.0)) AvgDiscountOnThresholdPercent
	,avg(iif(as1.SaleValue < p1.ListPrice, (p1.ListPrice - as1.SaleValue) / (p1.ListPrice), 0.0)) AvgDiscountPercent
from
	Auction.Sale as1
inner join
	Auction.Product ap1
on
	as1.AuctionProductID = ap1.AuctionProductID
left join
	Production.Product p1
on
	ap1.ProductID = p1.ProductID
left join
	Production.ProductSubcategory psc1
on
	p1.ProductSubcategoryID = psc1.ProductSubcategoryID
group by
	coalesce(psc1.Name, 'None') 
;
go

create or alter view Auction.FinancialAnalysis as 

	with sale_data1
	as
	(
		select 
			year(soh.OrderDate) SaleFiscalYear
			--,count(sod.SalesOrderDetailID) OrdersCount
			,count(distinct sod.ProductID) ProductsSold
			,sum(sod.OrderQty) SaleQuantity
			--,avg(sod.UnitPriceDiscount * sod.OrderQty) AveragePercentDiscount
			,sum((sod.UnitPrice * (1.0 - UnitPriceDiscount)) * OrderQty) SaleValue
			,avg(isnull(pch.StandardCost, p.StandardCost)) AvgStandardCostAtTime
			,sum(isnull(pch.StandardCost, p.StandardCost) * OrderQty) CostValue
			,sum(isnull(plph.ListPrice, p.ListPrice) * OrderQty) ListValue
		from 
			Sales.SalesOrderHeader soh
		inner join
			Sales.SalesOrderDetail sod
		on
			soh.SalesOrderID = sod.SalesOrderID
		left join
			Production.Product p
		on
			p.ProductID = sod.ProductID
		left join
			Production.ProductCostHistory pch
		on
			soh.OrderDate between pch.StartDate and coalesce(pch.EndDate, '99990101')
			and
			p.ProductID = pch.ProductID
		left join
			Production.ProductListPriceHistory plph
		on
			soh.OrderDate between plph.StartDate and coalesce(plph.EndDate, '99990101')
			and
			p.ProductID = plph.ProductID
		group by
			year(soh.OrderDate)
	), auction_data1 as
	(
		select 
			year(s.CreatedAt) AuctionFiscalYear
			,count(distinct ap.ProductID) AuctionProductsSold
			,sum(1) AuctionSaleQuantity
			,sum(s.SaleValue) AuctionSaleValue
			,avg(isnull(pch.StandardCost, p.StandardCost)) AuctionAvgStandardCostAtTime
			,sum(isnull(pch.StandardCost, p.StandardCost)) AuctionCostValue
			,sum(isnull(plph.ListPrice, p.ListPrice)) AuctionSaleListValue
		from 
			Auction.Sale s
		left join
			Auction.Product ap
		on
			s.AuctionProductID = ap.AuctionProductID
		left join
			Production.Product p
		on
			p.ProductID = ap.ProductID
		left join
			Production.ProductCostHistory pch
		on
			s.CreatedAt between pch.StartDate and coalesce(pch.EndDate, '99990101')
			and
			ap.ProductID = pch.ProductID
		left join
			Production.ProductListPriceHistory plph
		on
			s.CreatedAt between plph.StartDate and coalesce(plph.EndDate, '99990101')
			and
			ap.ProductID = plph.ProductID
		group by
			year(s.CreatedAt)
	)

	select
		sd.SaleFiscalYear FiscalYear
		,(datediff(D, (select TRY_CAST(Value as datetime) from Auction.Threshold where ThresholdID = 6), (select TRY_CAST(Value as datetime) from Auction.Threshold where ThresholdID = 7))) CampaignPerimeterDays
		,sd.ProductsSold
		,ad.AuctionProductsSold
		,sd.SaleQuantity
		,sd.CostValue 
		,sd.SaleValue
		,(sd.SaleValue - sd.CostValue) SalesProfit
		,((sd.SaleValue - sd.CostValue) / sd.SaleQuantity) AverageSaleProfit
		,ad.AuctionSaleQuantity
		,ad.AuctionCostValue
		,ad.AuctionSaleValue
		,(ad.AuctionSaleValue - ad.AuctionCostValue) AuctionProfit
		,((ad.AuctionSaleValue - ad.AuctionCostValue) / ad.AuctionSaleQuantity) AverageAuctionProfit
		,((ad.AuctionSaleValue - ad.AuctionCostValue) / (sd.SaleValue - sd.CostValue)) PercentAuctionOnSale
	from
		sale_data1 sd
	inner join
		auction_data1 ad
	on
		sd.SaleFiscalYear = ad.AuctionFiscalYear
; 
