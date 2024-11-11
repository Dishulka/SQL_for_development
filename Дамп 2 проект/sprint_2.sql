CREATE TYPE
	restaurant_type
AS ENUM
	('coffee_shop', 'restaurant', 'bar', 'pizzeria')
;


CREATE TABLE
	cafe.restaurants
	(
		restaurant_uuid UUID PRIMARY KEY DEFAULT GEN_RANDOM_UUID(),
		name VARCHAR(50) NOT NULL,
		location GEOGRAPHY,
		type restaurant_type,
		menu JSONB
	)
;


CREATE TABLE
	cafe.managers
	(
		manager_uuid UUID PRIMARY KEY DEFAULT GEN_RANDOM_UUID(),
		name VARCHAR(50) NOT NULL,
		phone VARCHAR(50)
	)
;


CREATE TABLE
	cafe.restaurant_manager_work_dates
	(
		restaurant_uuid UUID REFERENCES cafe.restaurants(restaurant_uuid),
		manager_uuid UUID REFERENCES cafe.managers(manager_uuid),
		date_employee INT,
		PRIMARY KEY(restaurant_uuid, manager_uuid)
	)
;


CREATE TABLE
	cafe.sales
	(
		date DATE,
		restaurant_uuid UUID REFERENCES cafe.restaurants(restaurant_uuid), 
		avg_check NUMERIC,
		PRIMARY KEY (date, restaurant_uuid)
	)
;


INSERT INTO
	cafe.restaurants
	(
		name,
		location,
		type,
		menu
	)
SELECT
	cafe_name,
	ST_Point(longitude, latitude)::GEOGRAPHY,
	type::restaurant_type,
	menu
FROM
	raw_data.sales
INNER JOIN
	raw_data.menu
USING
	(cafe_name)
GROUP BY
	cafe_name,
	latitude,
	longitude,
	type,
	menu
;


INSERT INTO
	cafe.managers
	(
		name,
		phone
	)
SELECT
	manager,
	manager_phone
FROM
	raw_data.sales
GROUP BY
	manager,
	manager_phone
;


WITH
	cafe_manager_date AS
	(
		SELECT
			cafe_name,
			manager,
			MIN(report_date) min_report_date,
			MAX(report_date) max_report_date
		FROM
			raw_data.sales
		GROUP BY
			cafe_name,
			manager
	)
INSERT INTO
	cafe.restaurant_manager_work_dates
	(
		restaurant_uuid,
		manager_uuid,
		date_employee
	)
SELECT
	restaurant_uuid,
	manager_uuid,
	max_report_date - min_report_date
FROM
	cafe_manager_date cmd
LEFT JOIN
	cafe.restaurants r
ON
	r.name = cmd.cafe_name
LEFT JOIN
	cafe.managers m
ON
	cmd.manager = m.name
;


INSERT INTO
	cafe.sales
	(
		date,
		restaurant_uuid,
		avg_check
	)
SELECT
	report_date,
	restaurant_uuid,
	avg_check
FROM
	raw_data.sales s
LEFT JOIN
	cafe.restaurants r
ON
	s.cafe_name = r.name	
;


-- 1 Задание
CREATE VIEW
	top_3_cafe_max_avg_check
AS
WITH
	cafe_avg_check
	AS
	(
		SELECT
			r.name,
			r.type,
			TRUNC(AVG(avg_check), 2) avg_check_cafe
		FROM
			cafe.sales s
		INNER JOIN
			cafe.restaurants r
		USING
			(restaurant_uuid)
		GROUP BY
			r.name,
			r.type
	),
	top_cafe_for_avg_check
	AS
	(
		SELECT
			*,
			ROW_NUMBER() OVER(PARTITION BY type ORDER BY avg_check_cafe DESC) num_string 
		FROM
			cafe_avg_check
	)
SELECT
	*
FROM
	top_cafe_for_avg_check
WHERE
	num_string in (1, 2, 3)
ORDER BY
	type
;


-- 2 Задание
CREATE MATERIALIZED VIEW
	change_avg_check_for_cafe
AS
WITH
	cafe_year_avg_check 
	AS
	(
		SELECT
			EXTRACT(YEAR FROM date) year_avg,
			name,
			type,
			TRUNC(AVG(avg_check), 2) avg_check
		FROM
			cafe.sales S
		INNER JOIN
			cafe.restaurants r
		USING
			(restaurant_uuid)
		GROUP BY
			year_avg,
			name,
			type
	),
	avg_check_cafe_prev_curr_year
	AS
	(
		SELECT
			*,
			LAG(avg_check) OVER(PARTITION BY name, type ORDER BY name, type, year_avg) avg_check_prev
		FROM
			cafe_year_avg_check
		WHERE
			year_avg <> 2023
		ORDER BY
			name,
			year_avg
	)
SELECT
	*,
	TRUNC((100 - avg_check * 100 / avg_check_prev), 2) change_check
FROM
	avg_check_cafe_prev_curr_year
;


-- 3 Задание
WITH
	count_manager_cafe
	AS
	(
		SELECT
			name,
			COUNT(DISTINCT manager_uuid) count_manager
		FROM
			cafe.restaurant_manager_work_dates
		JOIN
			cafe.restaurants
		USING
			(restaurant_uuid)
		GROUP BY
			name
		
	)
SELECT
	*
FROM
	count_manager_cafe
ORDER BY
	count_manager DESC
LIMIT 3
;


-- 4 Задание
WITH
	pizzeria
	AS
	(
		SELECT
			name,
			type,
			menu -> 'Пицца' pizzas
		FROM
			cafe.restaurants
		WHERE
			type = 'pizzeria'
	),
	pizza_for_cafe
	AS
	(
		SELECT
			*,
			JSONB_EACH(pizzas) name_pizza
		FROM
			pizzeria
	),
	count_pizza_in_cafe
	AS
	(
		SELECT
			name,
			COUNT(name_pizza) count_pizza
		FROM
			pizza_for_cafe
		GROUP BY
			name
	),
	top_pizzeria
	AS
	(
		SELECT
			*,
			RANK() OVER(ORDER BY count_pizza DESC) rang
		FROM
			count_pizza_in_cafe
	)
SELECT
	name,
	count_pizza
FROM
	top_pizzeria
WHERE
	rang = 1
;


-- 5 Задание
WITH
	pizzeria
	AS
	(
		SELECT
			name,
			'Пицца' type_food,
			key name_pizza,
			value price
		FROM
			cafe.restaurants,
			json_each_text((cafe.restaurants.menu -> 'Пицца')::JSON)
	),
	top_pizza
	AS
	(
		SELECT
			*,
			ROW_NUMBER() OVER(PARTITION BY name, type_food ORDER BY price DESC) top
		FROM
			pizzeria
	)
SELECT
	name, 
	type_food,
	name_pizza,
	price
FROM
	top_pizza
WHERE
	top = 1
ORDER BY
	name
;


-- 6 Задание
WITH
	distance_between_2_restaurant
	AS
	(
		SELECT
			r1.name name1,
			r2.name name2,
			r1.type,
			ST_Distance(r1.location::GEOGRAPHY, r2.location::GEOGRAPHY) distance
		FROM
			cafe.restaurants r1
		JOIN
			cafe.restaurants r2
		USING
			(type)
	),
	distance_between_2_diff_restaurant
	AS
	(
		SELECT
			*
		FROM
			distance_between_2_restaurant
		WHERE
			name1 <> name2
	),
	top_distance_between_restaurants
	AS
	(
		SELECT
			*,
			ROW_NUMBER() OVER(PARTITION BY type ORDER BY distance) num
		FROM
			distance_between_2_diff_restaurant
	)
SELECT
	name1,
	name2,
	type,
	distance
FROM
	top_distance_between_restaurants
WHERE
	num = 1
;



-- 7 Задание
WITH
	cafe_in_district
	AS
	(
		SELECT
			name,
			district_name
		FROM
			cafe.restaurants r
		JOIN
			cafe.districts d
		ON
			ST_Within
			(
				r.location::GEOMETRY,
				d.district_geom::GEOMETRY
			)
	),
	count_cafe_in_district
	AS
	(
		SELECT
			district_name,
			COUNT(name) count_cafe
		FROM
			cafe_in_district
		GROUP BY
			district_name
	),
	min_count_cafe_in_district
	AS
	(
		SELECT
			*
		FROM
			count_cafe_in_district
		ORDER BY 
			count_cafe
		LIMIT 1
	),
	max_count_cafe_in_district
	AS
	(
		SELECT
			*
		FROM
			count_cafe_in_district
		ORDER BY 
			count_cafe DESC
		LIMIT 1
	),
	rest_min_max_cafe_in_district
	AS
	(
		SELECT
			*
		FROM
			max_count_cafe_in_district
		UNION
		SELECT
			*
		FROM
			min_count_cafe_in_district
	)
SELECT
	*
FROM
	rest_min_max_cafe_in_district
ORDER BY
	count_cafe DESC
;















