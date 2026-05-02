--1Получить отчет по услугам            
WITH service_stats AS (
    SELECT 
        sp.id_service,
        sp.service_name,
        COUNT(ss.id_event) as total_orders,
        COUNT(CASE WHEN EXTRACT(YEAR FROM e.event_date) = EXTRACT(YEAR FROM CURRENT_DATE) THEN 1 END) as orders_current_year,
        SUM(ss.quantity * sp.cost) as total_revenue, --общая выручка
        SUM(CASE WHEN EXTRACT(YEAR FROM e.event_date) = EXTRACT(YEAR FROM CURRENT_DATE) 
            THEN ss.quantity * sp.cost ELSE 0 END) as revenue_current_year,
        COUNT(DISTINCT ss.id_event) as events_with_service,
        MAX(ss.quantity) as max_quantity_in_one_event
    FROM service_price sp
    JOIN selected_services ss ON sp.id_service = ss.id_service
    JOIN event e ON ss.id_event = e.id_event
    GROUP BY sp.id_service, sp.service_name
),
top_client_per_service AS (
    SELECT DISTINCT ON (sp.id_service)
        sp.id_service,
        c.fio as client_name,
        COUNT(*) as client_orders
    FROM service_price sp
    JOIN selected_services ss ON sp.id_service = ss.id_service
    JOIN event e ON ss.id_event = e.id_event
    JOIN contract ct ON e.id_contract = ct.id_contract
    JOIN client c ON ct.id_client = c.id_client
    GROUP BY sp.id_service, c.fio, c.id_client
    ORDER BY sp.id_service, COUNT(*) DESC
)
SELECT 
    ss.service_name,
    ss.total_orders,
    ss.orders_current_year,
    ss.total_revenue,
    ss.revenue_current_year,
    ss.events_with_service,
    ss.max_quantity_in_one_event,
    COALESCE(tc.client_name, 'Нет данных') as top_client_name,
    COALESCE(tc.client_orders, 0) as top_client_orders_count
FROM service_stats ss
LEFT JOIN top_client_per_service tc ON ss.id_service = tc.id_service
ORDER BY ss.total_orders DESC;


--2. Получить отчет о сотрудниках за прошлый месяц.
WITH last_month_events AS (
    SELECT *
    FROM event
    WHERE event_date >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month')
      AND event_date < DATE_TRUNC('month', CURRENT_DATE) --от первого дня прошлого месяца до первого дня текущего месяца	
),
employee_current_position AS (
    SELECT DISTINCT ON (hp.id_employee)
        hp.id_employee,
        p.position_name
    FROM history_position hp
    JOIN position p ON hp.id_position = p.id_position
    WHERE hp.end_date IS NULL
    ORDER BY hp.id_employee, hp.start_date DESC
),
managers_stats AS (
    SELECT 
        e.id_employee,
        COUNT(lme.id_event) as events_count,
        COALESCE(SUM(ct.amount), 0) as total_amount,
        COUNT(DISTINCT ct.id_client) as unique_clients
    FROM employee e
    JOIN last_month_events lme ON e.id_employee = lme.id_employee
    JOIN contract ct ON lme.id_contract = ct.id_contract
    GROUP BY e.id_employee
)
SELECT 
    e.fio,
    ecp.position_name,
    CASE 
        WHEN ecp.position_name = 'Manager' THEN COALESCE(ms.events_count::text, '0')
        ELSE 'Нет дан'
    END as metric1,
    CASE 
        WHEN ecp.position_name = 'Manager' THEN COALESCE(ms.total_amount::text, '0')
        ELSE 'Нет дан'
    END as metric2,
    CASE 
        WHEN ecp.position_name = 'Manager' THEN COALESCE(ms.unique_clients::text, '0')
        ELSE 'Нет дан'
    END as metric3
FROM employee e
JOIN employee_current_position ecp ON e.id_employee = ecp.id_employee
LEFT JOIN managers_stats ms ON e.id_employee = ms.id_employee
WHERE ecp.position_name IN ('Manager', 'Coordinator', 'Technician', 'Security', 'Organizer')
ORDER BY e.fio;


--Получить отчет о состоянии дел агентства по месяцам
WITH monthly_stats AS (
    SELECT 
        DATE_TRUNC('month', e.event_date) as month,
        COUNT(e.id_event) as events_count,
        SUM(ct.amount) as total_amount,
        AVG(ct.amount) as avg_amount
    FROM event e
    JOIN contract ct ON e.id_contract = ct.id_contract
    WHERE e.event_date >= DATE_TRUNC('year', CURRENT_DATE - INTERVAL '1 year')
      AND e.event_date < DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 year'
    GROUP BY DATE_TRUNC('month', e.event_date)
    ORDER BY month
),
popular_service_month AS (
    SELECT 
        DATE_TRUNC('month', e.event_date) as month,
        sp.service_name,
        COUNT(*) as service_count,
        ROW_NUMBER() OVER (PARTITION BY DATE_TRUNC('month', e.event_date) ORDER BY COUNT(*) DESC) as rn
    FROM selected_services ss
    JOIN service_price sp ON ss.id_service = sp.id_service
    JOIN event e ON ss.id_event = e.id_event
    WHERE e.event_date >= DATE_TRUNC('year', CURRENT_DATE - INTERVAL '1 year')
    GROUP BY DATE_TRUNC('month', e.event_date), sp.service_name
)
SELECT 
    TO_CHAR(ms.month, 'YYYY-MM') as month,
    ms.events_count,
    ms.total_amount,
    ROUND(ms.avg_amount, 2) as avg_amount,
    COALESCE(ROUND(((ms.total_amount - LAG(ms.total_amount) OVER (ORDER BY ms.month)) / 
        NULLIF(LAG(ms.total_amount) OVER (ORDER BY ms.month), 0)) * 100, 2), 0) as percent_change,
    COALESCE(ps.service_name, 'Нет дан') as top_service,
    COALESCE(ps.service_count, 0) as top_service_count,
    SUM(ms.total_amount) OVER (ORDER BY ms.month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as cumulative_sum --Накопительная сумма от первого месяца до текущего
FROM monthly_stats ms
LEFT JOIN popular_service_month ps ON ms.month = ps.month AND ps.rn = 1
ORDER BY ms.month;


--4Получить отчет по финансам за предыдущий месяц по мероприятиям, оформленным в том месяце. 
WITH days_of_month AS (
    SELECT 
        GENERATE_SERIES(
            DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month')::date,
            (DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '1 day')::date,
            '1 day'::interval
        )::date as day_date
),
daily_contracts AS (
    SELECT 
        DATE(conclusion_date) as day_date,
        COUNT(*) as contracts_count,
        SUM(amount) as contracts_amount
    FROM contract
    WHERE conclusion_date >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month')
      AND conclusion_date < DATE_TRUNC('month', CURRENT_DATE)
    GROUP BY DATE(conclusion_date)
),
daily_payments AS (
    SELECT 
        DATE(payment_date) as day_date,
        COUNT(*) as payments_count,
        SUM(amount) as payments_amount
    FROM payment_document
    WHERE payment_date >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month')
      AND payment_date < DATE_TRUNC('month', CURRENT_DATE)
    GROUP BY DATE(payment_date)
),
daily_debt AS (
    SELECT 
        dom.day_date,
        COALESCE(dc.contracts_count, 0) as contracts_count,
        COALESCE(dc.contracts_amount, 0) as contracts_amount,
        COALESCE(dp.payments_count, 0) as payments_count,
        COALESCE(dp.payments_amount, 0) as payments_amount,
        COALESCE(SUM(COALESCE(dc.contracts_amount, 0) - COALESCE(dp.payments_amount, 0)) --задолженность на начало дня = сумма всех (договоры − платежи) за предыдущие дни
            OVER (ORDER BY dom.day_date ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING), 0) as debt_start
    FROM days_of_month dom
    LEFT JOIN daily_contracts dc ON dom.day_date = dc.day_date
    LEFT JOIN daily_payments dp ON dom.day_date = dp.day_date
)
SELECT 
    TO_CHAR(day_date, 'DD Mon') as day_name,
    debt_start as debt_start_day,
    contracts_count,
    contracts_amount,
    payments_count,
    payments_amount,
    debt_start + contracts_amount - payments_amount as debt_end_day --долг на конец дня
FROM daily_debt

UNION all
SELECT 
    'ИТОГО' as day_name,
    0 as debt_start_day,
    SUM(contracts_count) as contracts_count,
    SUM(contracts_amount) as contracts_amount,
    SUM(payments_count) as payments_count,
    SUM(payments_amount) as payments_amount,
    SUM(contracts_amount) - SUM(payments_amount) as debt_end_day
FROM daily_debt;


--5. Получить отчет о самых дорогих праздниках. 
WITH event_costs AS (
    SELECT 
        e.id_event,
        e.id_contract, 
        e.name,
        e.event_date,
        c.fio as client_name,
        r.area * 500 as rent_cost,
        COUNT(DISTINCT p.id_celebrity) as celebrities_count,
        COALESCE(SUM(cel.fee), 0) as celebrities_total,
        COUNT(DISTINCT ss.id_service) as unique_services_count,
        COALESCE(SUM(ss.quantity), 0) as total_services_quantity, --сумма колво уник услуг
        COALESCE(SUM(ss.quantity * sp.cost), 0) as services_total --общая сумма услуг
    FROM event e
    JOIN contract ct ON e.id_contract = ct.id_contract
    JOIN client c ON ct.id_client = c.id_client	
    JOIN room r ON e.id_room = r.id_room
    LEFT JOIN selected_services ss ON e.id_event = ss.id_event
    LEFT JOIN service_price sp ON ss.id_service = sp.id_service
    LEFT JOIN performance p ON ct.id_contract = p.id_contract
    LEFT JOIN celebrity cel ON p.id_celebrity = cel.id_celebrity
    GROUP BY e.id_event, e.id_contract, e.name, e.event_date, c.fio, r.area
   -- HAVING (r.area * 500 + COALESCE(SUM(cel.fee), 0) + COALESCE(SUM(ss.quantity * sp.cost), 0)) > 500000
),
payments_sum AS (
    SELECT 
        id_contract,
        COALESCE(SUM(amount), 0) as paid_amount--.
    FROM payment_document
    GROUP BY id_contract
)
SELECT 
    ec.name AS event_name,
    ec.event_date,
    ec.client_name,
    ec.rent_cost AS base_price,
    ec.celebrities_count,
    ec.celebrities_total,
    ec.unique_services_count,
    ec.total_services_quantity,
    ec.services_total,
    ec.rent_cost,
    (ec.rent_cost + ec.celebrities_total + ec.services_total) as total_cost, 
    COALESCE(ps.paid_amount, 0) as paid_amount,
    (ec.rent_cost + ec.celebrities_total + ec.services_total) - COALESCE(ps.paid_amount, 0) as remaining_to_pay
FROM event_costs ec
LEFT JOIN payments_sum ps ON ec.id_contract = ps.id_contract  
ORDER BY total_cost DESC;

