USE olist;

-- RFM 마트 생성
CREATE TABLE mart_rfm AS
SELECT
    c.customer_unique_id,
    -- Recency: 기준일(데이터 최신 주문일)로부터 마지막 구매까지 경과일
    DATEDIFF(
        (SELECT MAX(order_purchase_timestamp) FROM orders),
        MAX(o.order_purchase_timestamp)
    ) AS recency,
    -- Frequency: 완료된 주문 횟수
    COUNT(DISTINCT o.order_id)          AS frequency,
    -- Monetary: 총 결제금액
    ROUND(SUM(p.payment_value), 2)      AS monetary
FROM customers c
JOIN orders o
    ON c.customer_id = o.customer_id
JOIN order_payments p
    ON o.order_id = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id;


-- 확인
SELECT * FROM mart_rfm LIMIT 10;
SELECT COUNT(*) FROM mart_rfm;

CREATE TABLE mart_delivery AS
SELECT
    o.order_id,
    c.customer_unique_id,
    c.customer_state,
    s.seller_id,
    s.seller_state,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    DATEDIFF(
        o.order_delivered_customer_date,
        o.order_purchase_timestamp
    ) AS actual_delivery_days,
    DATEDIFF(
        o.order_estimated_delivery_date,
        o.order_purchase_timestamp
    ) AS estimated_delivery_days,
    CASE
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
        THEN 1 ELSE 0
    END AS is_delayed,
    DATEDIFF(
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date
    ) AS delay_days
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN sellers s ON oi.seller_id = s.seller_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND YEAR(o.order_delivered_customer_date) > 1
  AND YEAR(o.order_estimated_delivery_date) > 1;
  
-- 확인: 전체 지연율
SELECT
    ROUND(AVG(is_delayed) * 100, 1) AS delay_rate_pct,
    ROUND(AVG(actual_delivery_days), 1) AS avg_actual_days,
    ROUND(AVG(delay_days), 1) AS avg_delay_days
FROM mart_delivery;  


-- 리뷰 마트 생성
CREATE TABLE mart_review AS
SELECT
    r.order_id,
    r.review_score,
    r.review_creation_date,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    c.customer_state,
    CASE
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
        THEN 1 ELSE 0
    END AS is_delayed,
    DATEDIFF(
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date
    ) AS delay_days,
    CASE
        WHEN r.review_score >= 4 THEN 'Positive'
        WHEN r.review_score = 3  THEN 'Neutral'
        ELSE 'Negative'
    END AS review_sentiment
FROM order_reviews r
JOIN orders o ON r.order_id = o.order_id
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND YEAR(o.order_delivered_customer_date) > 1
  AND YEAR(o.order_estimated_delivery_date) > 1;
  
  -- 확인: 감성별 배송 지연율
SELECT
    review_sentiment,
    COUNT(*) AS cnt,
    ROUND(AVG(is_delayed) * 100, 1) AS delay_rate_pct,
    ROUND(AVG(delay_days), 1) AS avg_delay_days
FROM mart_review
GROUP BY review_sentiment
ORDER BY avg_delay_days DESC;


-- 3개 마트 행 수 확인
SELECT 'mart_rfm'      AS mart, COUNT(*) AS row_cnt FROM mart_rfm
UNION ALL
SELECT 'mart_delivery' AS mart, COUNT(*) AS row_cnt FROM mart_delivery
UNION ALL
SELECT 'mart_review'   AS mart, COUNT(*) AS row_cnt FROM mart_review;


-- 실습과제
-- #1. RFM 마트에서 재구매 고객(Frequency >= 2) 비율은?
use olist;

select 
    count(*) as total_customers,
	sum(case when frequency >= 2 then 1 else 0 end) as repeat_customers,
    round(sum(case when frequency >= 2 then 1 else 0 end) * 100.0 / count(*),1) as pct
    
from mart_rfm;

-- #2. 배송 마트에서 지연율 가장 높은 고객 주 TOP3는 ?
select 
	seller_state,
    round(count(*) * 100.0 / sum(count(*)) over(),1)
from mart_delivery
group by seller_state
limit 3;

-- #3. 리뷰 마트에서 Negative 리뷰의 평균 지연 일수는?
select 
	abs(round(avg(delay_days),1)) as avg
from mart_review
where review_sentiment = "Negative";

-- #4. 배송 마트에서 판매자 주(seller_state)별 평균 배송 소요일 TOP 5는?
select
	seller_state,
	round(avg(actual_delivery_days),1) as avg_delivery
from mart_delivery
group by seller_state
order by avg_delivery desc
limit 5;

