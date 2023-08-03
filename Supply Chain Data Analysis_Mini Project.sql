--Task 1 : 
You have been provided a dataset of a company that supplies different types of paper to other businesses. 
The company wants to setup basic reporting using this data at hand.
The first task that you need to do before any analysis is done, is to create a database and insert the csv files into these tables.
You need to create a database named dwh. Within that database, you need to create the five tables
You will also need to insert the data into the five tables


create table if not exists Region(
ID int primary key,
Name varchar)

select * from region 

create table if not exists SALES_REP(
ID int not NULL,
Name varchar unique not NULL,
Region_id int,
primary key (ID),
foreign key(Region_id) references Region (ID) )

select * from sales_rep 

create table if not exists Accounts(
ID int not NULL,
Name varchar unique not null,
Website varchar,
LAT float,
LONG float,
Primary_poc varchar,
Sales_rep_id int not null,
primary key (ID),
foreign key(Sales_rep_id) references SALES_REP (ID) )

select * from accounts 

create table if not exists Web_events(
ID int not NULL,
Account_id int not null,
Occured_at Timestamp not null,
Channel varchar,
primary key (ID),
foreign key(Account_id) references Accounts (ID) )

select * from web_events 

create table if not exists Orders(
ID int not NULL,
Account_id int not null,
Occured_at Timestamp not null,
STANDARD_QTY int ,
GLOSS_QTY int ,
POSTER_QTY int ,
TOTAL int,
STANDARD_AMOUNT_USD float,
GLOSS_AMT_USD float,
POSTER_AMT_USD float,
TOTAL_AMT_USD float,
primary key (ID),
foreign key(Account_id) references Accounts (ID) )
 
select * from orders 


---Task 2 : 
-- i ) One of the reporting view that the business wants to setup is to track how the sales reps are performing. 

Which sales reps are handling which accounts?


with reps_accounts as (
	select sales_rep.id as sales_rep_id,
	sales_rep."name"  as sales_rep_name,
	sales_rep.region_id as sales_rep_region,
	accounts.name as account_name
	from sales_rep
	join accounts on accounts.sales_rep_id = sales_rep.id 
)
select *,row_number() over(partition by sales_rep_name) as acc_num
from reps_accounts
order by sales_rep_region;


-- ii)  One of the aspects that the business wants to explore is what has been the share of each sales representative's s year on year sales out of the total yearly sales

with final_table as (
	with sales_per_rep as (
		with sales_rep_order_hist as (
			select 
			orders.total_amt_usd as tot_rev,
			orders.occured_at  as order_time,
			date_part('month',orders.occured_at) as "month", 
			date_part('year',orders.occured_at) as "year",
			accounts."name"  as account_name,
			sales_rep."name" as sales_rep_name
			from orders
			join accounts on
			orders.account_id = accounts.id 
			join sales_rep on
			sales_rep.id = accounts.sales_rep_id 
			)
		select *,
		sum(tot_rev) over (partition by year) as yearly_total,
		sum(tot_rev) over (partition by sales_rep_name,"year") as sales_rep_rev,
		sum(tot_rev) over (partition by sales_rep_name,"year")/sum(tot_rev) over (partition by "year") as perc_sales_rep
		from sales_rep_order_hist
		order by year,sales_rep_name)
	select
		"year",
		"month",
		sales_rep_name,
		perc_sales_rep,
		dense_rank() over (partition by "year" order by perc_sales_rep desc) as rank_sales_rep,
		row_number() over (partition by sales_rep_name,"year") as row_num
		from sales_per_rep)
select "year",sales_rep_name,perc_sales_rep,rank_sales_rep
from final_table
where row_num=1;

---iii) Repeat the analysis given above but this time for region. Generate the percentage contribution of each region to total yearly revenue over years.
with final_table as (
	with sales_per_region as (
		with sales_region_order_hist as (
			select 
			orders.total_amt_usd as tot_rev,
			orders.occured_at  as order_time,
			date_part('month',orders.occured_at) as "month", 
			date_part('year',orders.occured_at) as "year",
			region."name"  as region_name
			from orders
			join accounts on
			orders.account_id = accounts.id 
			join sales_rep on
			sales_rep.id = accounts.sales_rep_id
			join region on 
			region.id = sales_rep.region_id 
			)
		select *,
		sum(tot_rev) over (partition by year) as yearly_total,
		sum(tot_rev) over (partition by region_name,"year") as region_rev,
		sum(tot_rev) over (partition by region_name,"year")/sum(tot_rev) over (partition by "year") as perc_sales_region
		from sales_region_order_hist
		order by year,region_name)
	select
		"year",
		"month",
		region_name,
		perc_sales_region,
		dense_rank() over (partition by "year" order by perc_sales_region desc) as rank_sales_region,
		row_number() over (partition by region_name,"year") as row_num
		from sales_per_region)
select "year",region_name,perc_sales_region,rank_sales_region
from final_table
where row_num=1;


---Task 3 
---The business wants to understand which accounts contribute to the bulk of the revenue and the business also wants to see year on year trend on the revenue contribution of each account.
--The final table should show revenue share of each account for each year's total revenue. 

with final_table as (
	with rev_acc as (
		with order_acc as (
			select 
			orders.occured_at as order_time,
			date_part('year',orders.occured_at) as "year", 
			orders.total_amt_usd  as total_rev,
			accounts."name"  as acc_name,
			accounts.id as acc_id
			from orders 
			join accounts 
			on orders.account_id = accounts.id) 
		select "year",acc_name, sum(total_rev) as rev
		from order_acc
		group by "year",acc_name
		order by "year")
	select *,
	rev/sum(rev) over (partition by "year") as pct_yearly_rev
	from rev_acc)
select *,
dense_rank() over (partition by "year" order by pct_yearly_rev desc) as rev_rank
from final_table;

