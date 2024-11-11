CREATE SCHEMA  
	raw_data; 
 
 
CREATE TABLE  
	raw_data.sales 
( 
	id SMALLINT PRIMARY KEY, 
	auto VARCHAR, 
	gasoline_consumption NUMERIC(4, 2), 
	price numeric(9, 2), 
	date DATE, 
	person VARCHAR, 
	phone VARCHAR, 
	discount SMALLINT, 
	brand_origin VARCHAR 
) 
; 
 
 
COPY 
	raw_data.sales 
FROM 
	'C:/TempForSQL/cars.csv' 
WITH 
	CSV 
	HEADER 
	NULL 'null' 
; 
 
 
CREATE SCHEMA car_shop; 
 
 
CREATE TABLE  
	car_shop.client 
( 
	-- Первичный ключ таблицы => тип с автоинкриментом SERIAL 
	client_id SERIAL PRIMARY KEY, 
	-- ФИО клиента. Сюда входит имя, фамилия и отчество, поэтому делаем длину строки 100 
	name VARCHAR(100) NOT NULL, 
	-- Номер телефона клиента. В номер телефона могут входить: скобки (), знак +, тире - => VARCHAR. Номер уникальный 
	phone VARCHAR(50) NOT NULL UNIQUE 
) 
; 


CREATE TABLE
	car_shop.brand_origin
(
	-- Первичный ключ таблицы => тип с автоинкриментом SERIAL 
	brand_origin_id SERIAL PRIMARY KEY, 
	-- Страна происхождения бренда машины не более 20 символов. Может быть NULL
	brand_origin_name VARCHAR(20) 
)
; 


CREATE TABLE  
	car_shop.car_brand 
( 
	-- Первичный ключ таблицы => тип с автоинкриментом SERIAL 
	car_brand_id SERIAL PRIMARY KEY, 
	-- Название бренда машины не более 20 символов 
	name VARCHAR(20) NOT NULL, 
	-- Внешний ключ (отсылает к таблице car_shop.brand_origin). id названия страны происхождения машины - цело число 
	brand_origin_id INT REFERENCES car_shop.brand_origin(brand_origin_id) 
) 
; 
 
 
CREATE TABLE 
	car_shop.color 
( 
	-- Первичный ключ таблицы => тип с автоинкриментом SERIAL 
	color_id SERIAL PRIMARY KEY, 
	-- Название цвета не более 20 символов 
	name VARCHAR(20) NOT NULL 
) 
; 
 
 
CREATE TABLE  
	car_shop.car_name 
( 
	-- Первичный ключ таблицы => тип с автоинкриментом SERIAL 
	car_name_id SERIAL PRIMARY KEY, 
	-- Название машины не более 20 символов 
	name VARCHAR(20) NOT NULL, 
	-- Потребление бензина. Дробное число не может быть трехзначным. Может быть NULL 
	gasoline_consumption NUMERIC(4, 2),
	-- Внешний ключ (отсылает к таблице car_shop.car_brand). id названия бренда машины - целое число 
	car_brand_id INT REFERENCES car_shop.car_brand(car_brand_id) 
) 
; 
 
 
CREATE TABLE  
	car_shop.car 
( 
	-- Первичный ключ таблицы => тип с автоинкриментом SERIAL 
	car_id SERIAL PRIMARY KEY, 
	-- Внешний ключ (отсылает к таблице car_shop.car_name). id названия машины - цело число 
	car_name_id INT REFERENCES car_shop.car_name(car_name_id), 
	-- Внешний ключ (отсылает к таблице car_shop.color). id названия цвета машины - цело число 
	color_id INT REFERENCES car_shop.color(color_id) 
) 
; 
 
 
CREATE TABLE 
	car_shop.order 
( 
	-- Первичный ключ таблицы => тип с автоинкриментом SERIAL 
	order_id SERIAL PRIMARY KEY, 
	-- Внешний ключ (отсылает к таблице car_shop.client). id клиента, который совершил покупку - цело число 
	client_id INT REFERENCES car_shop.client, 
	-- Дата покупки. Значение по умолчанию = текущая дата 
	order_date DATE DEFAULT CURRENT_DATE, 
	-- целое число - размер скидки в процентах (от 0 до 100). По умолчанию размер скидки = 0 
	discount SMALLINT DEFAULT 0, 
	-- Цена в $ за покупку. Дробное число не больше семизначной суммы, содержит только сотые. Повышенная точность 
	price NUMERIC(9, 2) NOT NULL, 
	-- Внешний ключ (отсылает к таблице car_shop.car). id машины, которую приобрел клиент - цело число 
	car_id INT REFERENCES car_shop.car 
) 
; 
 
 
INSERT INTO 
	car_shop.client 
( 
	name, 
	phone 
) 
SELECT DISTINCT 
	person, 
	phone 
FROM 
	raw_data.sales 
; 
 

INSERT INTO 
	car_shop.color 
( 
	name 
) 
SELECT DISTINCT 
	SUBSTR(auto, STRPOS(auto, ',') + 2) 
FROM  
	raw_data.sales 
; 


INSERT INTO
	car_shop.brand_origin
(
	brand_origin_name
)
SELECT DISTINCT
	brand_origin
FROM
	raw_data.sales 
; 


INSERT INTO  
	car_shop.car_brand 
( 
	name, 
	brand_origin_id
) 
SELECT DISTINCT
	SPLIT_PART(s.auto, ' ', 1), 
	bo.brand_origin_id
FROM 
	raw_data.sales s
LEFT JOIN
	car_shop.brand_origin bo
ON
	s.brand_origin = bo.brand_origin_name
;


INSERT INTO 
	car_shop.car_name 
( 
	name, 
	gasoline_consumption,
	car_brand_id
) 
SELECT DISTINCT 
	SUBSTR(s.auto, STRPOS(auto, ' ') + 1, STRPOS(auto, ',') - STRPOS(auto, ' ') - 1), 
	s.gasoline_consumption,
	cb.car_brand_id
FROM  
	raw_data.sales s
LEFT JOIN 
	car_shop.car_brand cb
ON 
	SPLIT_PART(s.auto, ' ', 1) = cb.name
; 

 
INSERT INTO 
	car_shop.car 
( 
	car_name_id, 
	color_id 
) 
SELECT DISTINCT 
	cn.car_name_id, 
	c.color_id 
FROM 
	raw_data.sales  
LEFT JOIN  
	car_shop.car_name cn 
ON  
	SUBSTR(auto, STRPOS(auto, ' ') + 1, STRPOS(auto, ',') - STRPOS(auto, ' ') - 1) = cn.name 
LEFT JOIN 
	car_shop.color c 
ON 
	SUBSTR(auto, STRPOS(auto, ',') + 2) = c.name 
; 


INSERT INTO 
	car_shop.order 
( 
	client_id, 
	order_date, 
	discount, 
	price, 
	car_id 
) 
SELECT DISTINCT
	c.client_id, 
	s.date, 
	s.discount, 
	s.price, 
	ca.car_id 
FROM 
	raw_data.sales s 
LEFT JOIN 
	car_shop.client c 
ON 
	s.person = c.name 
LEFT JOIN 
	car_shop.car_name cn 
ON 
	SUBSTR(auto, STRPOS(auto, ' ') + 1, STRPOS(auto, ',') - STRPOS(auto, ' ') - 1) = cn.name 
LEFT JOIN 
	car_shop.color col 
ON 
	SUBSTR(auto, STRPOS(auto, ',') + 2) = col.name 
LEFT JOIN 
	car_shop.car ca 
ON 
	cn.car_name_id = ca.car_name_id 
WHERE 
	ca.car_name_id = cn.car_name_id 
	AND ca.color_id = col.color_id 
; 
 
 
-- Задание 1 
SELECT  
	(COUNT(*) - COUNT(cn.gasoline_consumption)) * 100 / COUNT(*)::REAL nulls_percentage_gasoline_consumption 
FROM  
	car_shop.car_name cn 
; 
 

-- Задание 2 
SELECT 
	cb.name brand_name, 
	EXTRACT(YEAR FROM o.order_date) year_avg, 
	ROUND(AVG(o.price), 2) price_avg 
	
FROM 
	car_shop.car_brand cb	 
JOIN
	car_shop.car_name cn
USING
	(car_brand_id)
JOIN
	car_shop.car ca
USING
	(car_name_id)
JOIN  
	car_shop.order o 
USING 
	(car_id) 
GROUP BY 
	year_avg, 
	brand_name 
ORDER BY 
	brand_name, 
	year_avg 
; 
 
 
-- Задание 3 
SELECT 
	EXTRACT(MONTH FROM o.order_date) month_avg, 
	EXTRACT(YEAR FROM o.order_date) year_avg, 
	ROUND(AVG(o.price), 2) price_avg 
FROM 
	car_shop.order o 
WHERE 
	o.order_date BETWEEN '2022-01-01' AND '2022-12-31' 
GROUP BY 
	month_avg, 
	year_avg 
ORDER BY 
	month_avg 
; 
 
 
-- Задание 4 
SELECT 
	c.name, 
	STRING_AGG(CONCAT(cb.name, ' ', cn.name), ', ') cars 
FROM 
	car_shop.client c 
LEFT JOIN 
	car_shop.order o 
USING 
	(client_id) 
LEFT JOIN 
	car_shop.car ca 
USING 
	(car_id)  
LEFT JOIN 
	car_shop.car_name cn 
USING 
	(car_name_id) 
LEFT JOIN 
	car_shop.car_brand cb 
USING 
	(car_brand_id)
GROUP BY 
	c.name 
ORDER BY 
	c.name; 
 
 
-- Задание 5 
SELECT 	
	bo.brand_origin_name, 
	MAX(o.price * 100 / (100 - o.discount)) price_max, 
	MIN(o.price * 100 / (100 - o.discount)) price_min 
	
FROM 
	car_shop.car ca
LEFT JOIN
	car_shop.car_name cn
USING
	(car_name_id)
LEFT JOIN 
	car_shop.car_brand cb 
USING 
	(car_brand_id) 
LEFT JOIN
	car_shop.brand_origin bo
USING
	(brand_origin_id)
LEFT JOIN 
	car_shop.order o 
USING 
	(car_id) 
GROUP BY 
	bo.brand_origin_name
HAVING 
	bo.brand_origin_name IS NOT NULL 
; 
 
 
-- Задание 6 
SELECT 
	COUNT(c.client_id) persons_from_usa_count 
FROM 
	car_shop.client c 
WHERE 
	c.phone LIKE '+1%' 
; 
