{ "sql": "SELECT u.gender as gender, COUNT(*) as aggCount FROM users u INNER JOIN ratings r ON u.user_id = r.user_id GROUP BY gender" }
