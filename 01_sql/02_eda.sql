USE olist;

-- 2. orders 
-- 2-1. 전체 주문 건수 , 기간
SELECT 
	count(*) as total_counts,
    min(order_purchase_timestamp) as first_order,
    max(order_purchase_timestamp) as last_order
    
from orders;

-- 2-2. 주문 상태별 건수 , 퍼센테이지
-- 배송완료 96478(97%)

select 
	order_status, 
	count(*) as cnt,
    round(count(*) * 100.0/sum(count(*)) over() , 1) as pct
from orders
group by order_status
order by cnt desc;

-- 2-3. 월별 주문 추이 (취소건 제외)
-- BEST5 : 17년 11월, 18년 1월/3월/4월/5월

SELECT 
	date_format(order_purchase_timestamp, '%Y-%m') as order_month,
    count(*) as order_cnt
from orders
where order_status != 'canceled'
group by order_month
order by order_cnt desc;

-- 3. order_payments
-- 3-1. 전체 매출, 평균 주문 금액, 최대 주문 금액
select 
	round(SUM(payment_value),0) as total_revenue,
    round(AVG(payment_value),2) as average_revenue,
    round(MAX(payment_value),2) as max_revenue

from order_payments
where payment_type != 'not_defined';

-- 3-2. 카테고리별 매출 TOP 10
select 
	coalesce(t.product_category_name_english,
    p.product_category_name, 'Unknown') as category,
    count(DISTINCT oi.order_id) as order_cnt,
    round(sum(oi.price), 0) as revenue
from order_items oi
join products p on oi.product_id = p.product_id
left join category_translation t on p.product_category_name = t.product_category_name
group by category
order by revenue desc
limit 10;

-- 3-3. 결제수단별 비중
select 
	payment_type,
    count(*) as cnt,
    round(count(*) * 100 / sum(count(*)) over(), 1) as pct
from order_payments
group by payment_type
order by cnt desc;

-- 4.orders
-- 4-1. 배송 소요일 분석 (실제vs예상)
select 
	round(avg(datediff(order_delivered_customer_date, order_purchase_timestamp)),1) as avg_actual_days,
	round(avg(datediff(order_estimated_delivery_date, order_purchase_timestamp)),1) as avg_estimated_days
    
    from orders
    where order_delivered_customer_date is not null;
    
-- 4-2. 배송 소요일 분포 (구간별)
select 
	case
		when datediff(order_delivered_customer_date, order_purchase_timestamp) <= 7 then '7일 이내'
        when datediff(order_delivered_customer_date, order_purchase_timestamp) <= 14 then '8-14일 이내'
        when datediff(order_delivered_customer_date, order_purchase_timestamp) <= 21 then '15-21일 이내'
		else '22일 이상'
	end as delivery_range,
    count(*) as ant
from orders
where order_delivered_customer_date is not null
group by delivery_range
order by min(datediff(order_delivered_customer_date, order_purchase_timestamp));

-- 5.order_reviews
-- 5-1. 리뷰 분포
select 
	review_score, 
    count(*) as cnt, 
    round(count(*) * 100.0 / sum(count(*)) over(),1) as pct
from order_reviews
group by review_score
order by review_score desc;
		
-- 5-2. 배송 지연과 리뷰 점수의 관계성
select 
	case
		when order_delivered_customer_date > order_estimated_delivery_date then '지연'
		else '정시/조기'
	end as delivery_status,
    round(avg(r.review_score), 2) as avg_review_score,
    count(*) as cnt
    
from orders o
join order_reviews r on r.order_id = o.order_id
where o.order_delivered_customer_date is not null
group by delivery_status;
      
-- 6. 데이터 이상, 결측치 체크
-- 6-1.  orders null값 확인
select
	count(*) as total,
    sum(case when order_approved_at is null then 1 else 0 end) as null_approved,
    sum(case when order_delivered_carrier_date is null then 1 else 0 end) as null_carrier,
    sum(case when order_delivered_customer_date is null then 1 else 0 end) as null_delivered
    from orders;

-- 6-2. product 결측치 현황 
select
	count(*) as total,
    sum(case when product_category_name is null then 1 else 0 end) as null_category,
    sum(case when product_weight_g = 0 or product_weight_g is null then 1 else 0 end) as zero_weight
from products;

-- 6-3. 이상치-비정상적으로 높은 주문
select order_id, payment_value
from order_payments
where payment_value > 5000
order by payment_value desc
limit 10;

-- 실습 과제
-- 01. 가장 주문이 많은 요일은?
select 
	dayname(order_purchase_timestamp) as day,
    count(*) as cnt
from orders
group by day
order by cnt desc;     

-- 02. 신용카드 할부 평균 개월 수는?
select 
	round(avg(payment_installments),0) as avg_installments
from order_payments
where payment_type = 'credit_card';

-- 03. 리뷰 점수 1점 주문 중 배송 지연 비율은?


select 
    case
		when o.order_estimated_delivery_date > o.order_delivered_customer_date then '지연' else "정시배송" end as deliver_status,
        round(count(*) * 100.0 / sum(count(*)) over(), 1) as pct,
        COUNT(*) AS order_cnt
from order_reviews r
join orders o on r.order_id = o.order_id
where r.review_score = 1
group by deliver_status;

-- #4. 판매자가 가장 많은 주는?

select 
	seller_state as state,
    count(*) as cnt
from sellers
group by state
order by cnt desc
limit 5;

-- #5. 평균 상품 무게는?
select round(avg(product_weight_g),1) as avg_weight
from products
where product_weight_g >0;

