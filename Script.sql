/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
SELECT COUNT(DISTINCT id) AS all_users, -- считаем всех пользователей
SUM(payer) AS payers, -- сколько игроков платит за валюту
AVG(payer) AS payers_share -- доля платящих игроков
FROM fantasy.users

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT r.race,
SUM(u.payer) AS payers, -- расчёты как предыдущем запросе
COUNT(DISTINCT u.id) AS all_users,
AVG(u.payer) AS payers_share
FROM fantasy.users AS u
JOIN fantasy.race AS r USING(race_id)
GROUP BY r.race-- группируем, чтобы найти значения в разрезе расы
ORDER BY payers_share DESC -- сортировка по популярности у игроков

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT COUNT(amount) AS nb_purchases,  --считаем количество покупок
SUM(amount) AS total_cost, -- сумму всех покупок
MIN(amount) AS min_cost, -- минимальную стоимость покупки
MAX(amount) AS max_cost, -- максимальную стоимость покупки
ROUND(AVG(amount)::NUMERIC,2) AS avg_cost,  --среднее значение
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS median, -- медиану
ROUND(STDDEV(amount)::NUMERIC,2) AS stand_dev  -- и стандартное отклонение
FROM fantasy.events

-- 2.2: Аномальные нулевые покупки:
WITH CTE AS(
SELECT COUNT(amount) AS null_purchases -- находим количество нулевых покупок
FROM fantasy.events 
WHERE amount = 0),
CTE2 AS(
SELECT COUNT(amount) AS total_purchases -- общее количество покупок
FROM fantasy.events)
SELECT null_purchases,
null_purchases::numeric/total_purchases::numeric AS null_purchases_share -- и долю нулевых покупок от общих
FROM CTE,CTE2

-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
SELECT 
CASE 
	WHEN u.payer = '0' 
	THEN 'неплатящие'
	ELSE 'платящие'
END AS players,
COUNT(DISTINCT u.id) AS all_players,
COUNT(e.transaction_id)/COUNT(DISTINCT u.id)::NUMERIC AS avg_purchases,
SUM(e.amount)/COUNT(DISTINCT u.id)::NUMERIC AS avg_cost
FROM fantasy.events AS e
RIGHT JOIN fantasy.users AS u ON e.id = u.id
WHERE e.amount >0
GROUP BY players

-- 2.4: Популярные эпические предметы:
WITH CTE AS(
SELECT game_items AS item,
COUNT(transaction_id) AS total_purchases_by_item,  -- посчитаем сколько покупок было сделано для каждого предмета
COUNT(DISTINCT id) AS users_by_item  -- и сколько игроков купили тот или иной предмет
FROM fantasy.items AS i
LEFT JOIN fantasy.events AS e ON i.item_code = e.item_code
GROUP BY game_items),
CTE2 AS (
SELECT COUNT(transaction_id) AS total_purchases -- для упрощения основного запроса посчитаем количество всех совершенных покупок предметов в сте
FROM fantasy.events),
CTE3 AS (
SELECT COUNT(DISTINCT id) AS all_users
FROM fantasy.events)
SELECT cte.item, 
total_purchases_by_item, 
ROUND(total_purchases_by_item::numeric/total_purchases::NUMERIC,4) AS item_purchases_share, -- найдем долю каждого предмета в разрезе всех покупок
ROUND(users_by_item::NUMERIC/all_users::NUMERIC,4) AS players_share -- и долю игроков, купивших тот или иной предмет
FROM CTE, CTE2,CTE3
ORDER BY players_share DESC
-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:
WITH CTE AS ( 
SELECT race,
COUNT(DISTINCT id) AS all_users, -- находим общее количество игроков
COUNT(amount) AS all_purchases, -- все покупки
SUM(amount) AS sum_cost  -- и их сумму
FROM fantasy.race
LEFT JOIN fantasy.users USING (race_id)
LEFT JOIN fantasy.events USING (id)
GROUP BY race),
CTE2 AS (
SELECT race,
COUNT(DISTINCT id) AS users_with_purchases -- выделяем игроков, которые совершали покупки
FROM fantasy.race
LEFT JOIN fantasy.users USING (race_id)
LEFT JOIN fantasy.events USING (id)
WHERE amount >0
GROUP BY race),
CTE3 AS (
SELECT race,
COUNT(DISTINCT id) AS payers -- находим игроков, которые не только совершали покупки, но и тратили реальные деньги
FROM fantasy.race
LEFT JOIN fantasy.users USING (race_id)
LEFT JOIN fantasy.events USING (id)
WHERE amount >0 AND payer = '1'
GROUP BY race)
SELECT cte.race,
all_users,
users_with_purchases,
ROUND(users_with_purchases/all_users::NUMERIC,2) AS users_wp_share,  -- считаем долю игроков с покупками
ROUND(payers/users_with_purchases::NUMERIC,2) AS payers_share, -- долю платящих игроков
ROUND(all_purchases/users_with_purchases::NUMERIC,2) AS avg_purchases, -- среднее количество покупок на игрока
ROUND(sum_cost::NUMERIC/all_purchases::NUMERIC,2) AS avg_cost, -- среднюю стоимость одной покупки
ROUND(sum_cost::NUMERIC/users_with_purchases::NUMERIC,2) AS avg_sum_cost -- и среднюю стоимость всех покупок на игрока
FROM CTE
JOIN CTE2 USING(race)
JOIN CTE3 USING(race)
