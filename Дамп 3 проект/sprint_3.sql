--Задание 1
CREATE OR REPLACE PROCEDURE 
	update_employees_rate
	(
    	data_employee JSON
	)
LANGUAGE plpgsql
AS
$$
BEGIN
	FOR _i IN 0..(JSON_ARRAY_LENGTH(data_employee)-1)
  	LOOP
    	UPDATE employees
	    SET rate =
			CASE
				WHEN
					(rate * (100 + (data_employee->_i->>'rate_change')::NUMERIC) / 100) < 500
				THEN
					500
				ELSE
					(rate * (100 + (data_employee->_i->>'rate_change')::NUMERIC) / 100)
			END
	    WHERE id = (data_employee->_i->>'employee_id')::UUID;
  	END LOOP;
END;
$$;


--Задание 2
CREATE OR REPLACE PROCEDURE 
	indexing_salary
	(
		p INT
	)
LANGUAGE plpgsql
AS
$$
DECLARE
	_avg_salary NUMERIC;
BEGIN
	_avg_salary = (SELECT
				    	AVG(rate)
				   FROM
						employees
				  );

	UPDATE
		employees
	SET
		rate = 
			CASE
				WHEN rate < _avg_salary
				THEN ROUND(rate * (100 + p + 2) / 100)::INT
				ELSE ROUND(rate * (100 + p) / 100)::INT
			END
	;
		
END;
$$;


--Задание 3
CREATE OR REPLACE PROCEDURE 
	close_project
	(
		project_uuid UUID
	)
LANGUAGE plpgsql
AS
$$
DECLARE
	_find_false INT;
	_wasted_hours INT = 0;
	_get_bonus INT = 0;
	_plan_time INT;
	_count_employee INT;
	_bonus_time INT;
	_employee UUID;
BEGIN
	SELECT 
		COUNT(*)
    INTO 
		_find_false
    FROM 
		projects
    WHERE 
		is_active = false
		AND id = project_uuid
	;


	IF 
		_find_false > 0 
	THEN
    	RAISE EXCEPTION 'Проект уже закрыт.';
  	END IF;
		
	
	UPDATE
		projects
	SET
		is_active = false
	WHERE
		id = project_uuid
	;


	SELECT 
		SUM(work_hours)
    INTO 
		_wasted_hours
    FROM 
		logs
	WHERE
		project_id = project_uuid
	;


	SELECT 
		estimated_time
    INTO 
		_plan_time
    FROM 
		projects
    WHERE 
		id = project_uuid
	;	


	IF
		(_plan_time IS NOT NULL) AND (_plan_time > _wasted_hours)
	THEN
		_get_bonus = 1;
	END IF;

	
	SELECT
		COUNT (DISTINCT employee_id)
	INTO
		_count_employee
    FROM 
		logs
	WHERE
		project_id = project_uuid
	;


	IF _count_employee > 0 
	THEN 
        _bonus_time := FLOOR((_plan_time - _wasted_hours) * 3 / 4 / _count_employee);
	END IF;


	IF 
		(_bonus_time > 16)
	THEN
		_bonus_time := 16;
	END IF;

	
	IF _get_bonus = 1
	THEN
		FOR _employee IN
			SELECT DISTINCT
				employee_id
		    FROM 
				logs
			WHERE
				project_id = project_uuid
		LOOP
			INSERT INTO
				logs
				(
					employee_id,
					project_id,
					work_date,
					work_hours
				)
			VALUES
				(
					_employee,
					project_uuid,
					CURRENT_DATE,
					_bonus_time
				);
		END LOOP;
	END IF;

	
END;
$$;


--Задание 4
CREATE OR REPLACE PROCEDURE
	log_work
	(
		p_employee_id UUID,
		p_project_id UUID,
		p_date DATE,
		p_worked_house INT
	)
LANGUAGE plpgsql
AS
$$
DECLARE
	_required_review BOOLEAN := false;
	_logs_hours INT;
BEGIN
	IF
		(SELECT
			is_active
		FROM
			projects
		WHERE
			id = p_project_id) 
		is false
	THEN
		RAISE EXCEPTION 'Project closed';
	END IF;

	IF
		(p_worked_house < 1 OR p_worked_house > 24)
	THEN
		RAISE NOTICE 'Invalid data';
		RETURN;
	END IF;

	SELECT
		SUM(work_hours)
	INTO
		_logs_hours
	FROM
		logs
	WHERE
		employee_id = p_employee_id
		AND work_date = p_date
	;

	IF
		(p_date > CURRENT_DATE) OR (p_date <= (CURRENT_DATE - ('7 days')::interval)::DATE) OR (_logs_hours > 16)
	THEN
		_required_review := true;
	END IF;
	
	INSERT INTO
		logs
		(
			employee_id,
			project_id,
			work_date,
			work_hours,
			required_review
		)
	VALUES
		(
			p_employee_id,
			p_project_id,
			p_date,
			p_worked_house,
			_required_review
		)
	;

END;
$$;


-- Задание 5
CREATE TABLE
	employee_rate_history
	(
		id UUID PRIMARY KEY DEFAULT GEN_RANDOM_UUID(),
		employee_id UUID REFERENCES employees(id),
		rate INT NOT NULL,
		from_date DATE NOT NULL
	)
;

CREATE OR REPLACE PROCEDURE
	add_start_employee()
LANGUAGE plpgsql
AS
$$
DECLARE
	_employee_info record;
BEGIN
	FOR _employee_info IN
		SELECT
			id,
			rate
		FROM
			employees
	LOOP
		INSERT INTO
			employee_rate_history
			(
				employee_id,
				rate,
				from_date
			)
		VALUES
			(
				_employee_info.id,
				_employee_info.rate,
				'2020-12-26'
			)
		;
	END LOOP;	

END;
$$
;

CALL add_start_employee();

CREATE OR REPLACE FUNCTION
	save_employee_rate_history()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN

	INSERT INTO
		employee_rate_history
		(
			employee_id,
			rate,
			from_date
		)
	VALUES
		(
			NEW.id,
			NEW.rate,
			CURRENT_DATE
		)
	;

	RETURN NULL;

END;
$$;


CREATE OR REPLACE TRIGGER
	change_employee_rate
AFTER
INSERT OR UPDATE OF rate
ON employees
FOR EACH ROW
EXECUTE FUNCTION save_employee_rate_history();


-- Задание 6*
CREATE OR REPLACE FUNCTION
	best_project_workers
	(
		p_id_project UUID
	)
RETURNS TABLE
 	(
	    employee TEXT,
	    all_work_hours BIGINT
	)
LANGUAGE plpgsql
AS $$
BEGIN
  
	RETURN QUERY
	WITH 
  	employee_sum_hours AS
  	(
		SELECT
	    	e.name AS employee,
	    	SUM(l.work_hours) AS all_work_hours,
	    	COUNT(l.work_date) AS work_date
	    FROM
	    	logs l
	    JOIN
	    	employees e
	    ON
	    	l.employee_id = e.id
	    WHERE
	    	l.project_id = p_id_project
	    GROUP BY
	    	e.id
  	)
	SELECT
  		ranked_employees.employee,
    	ranked_employees.all_work_hours
  	FROM 
	(
		SELECT 
	    	employee_sum_hours.employee,
	    	employee_sum_hours.all_work_hours,
	    	RANK() OVER(ORDER BY employee_sum_hours.all_work_hours DESC, employee_sum_hours.work_date DESC) rank
	    FROM 
	    	employee_sum_hours
  	) ranked_employees
  	ORDER BY
		rank
  	LIMIT 3;

END;
$$;

SELECT employee, all_work_hours FROM best_project_workers(
    '2dfffa75-7cd9-4426-922c-95046f3d06a0' -- Project UUID
);


-- Задание 7
CREATE OR REPLACE FUNCTION
	calculate_month_salary
	(
		p_start_month DATE,
		p_end_month DATE
	)
RETURNS TABLE
	(
		id UUID,
		employee TEXT,
		worked_hours INT,
		salary NUMERIC
	)
LANGUAGE plpgsql
AS $$
DECLARE
	_warning_variable record;
BEGIN

	FOR _warning_variable IN
			SELECT
				e.id,
				l.required_review
			FROM
				logs l
			JOIN
				employees e
			ON
				l.employee_id = e.id
			WHERE
				l.work_date >= p_start_month AND l.work_date <= p_end_month
	LOOP
		IF _warning_variable.required_review = true
		THEN 
			RAISE WARNING 'Warning! Employee % hours must be reviewed!', _warning_variable.id;
		END IF;
	END LOOP
	;

	RETURN QUERY
	WITH
		total_sum_work_hours AS
		(
			SELECT
				e.id,
				e.name,
				e.rate,
				SUM(l.work_hours)::INT sum_worked_hours
			FROM
				logs l
			JOIN
				employees e
			ON
				l.employee_id = e.id
			WHERE
				l.work_date >= p_start_month AND l.work_date <= p_end_month
				AND l.required_review = false AND l.is_paid = false
			GROUP BY
				e.id,
				e.name,
				e.rate
		)
	SELECT
		total_sum_work_hours.id,
		total_sum_work_hours.name,
		total_sum_work_hours.sum_worked_hours,
		CASE
			WHEN total_sum_work_hours.sum_worked_hours <= 160 THEN (total_sum_work_hours.sum_worked_hours * total_sum_work_hours.rate)::NUMERIC
			ELSE (160 * total_sum_work_hours.rate + (total_sum_work_hours.sum_worked_hours - 160) * total_sum_work_hours.rate * 1.25)::NUMERIC
		END
	FROM
		total_sum_work_hours
	;
	
END;
$$;

SELECT * FROM calculate_month_salary(
    '2023-10-01',  -- start of month
    '2023-10-31'   -- end of month
);










