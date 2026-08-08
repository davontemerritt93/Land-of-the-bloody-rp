-- Optional LOTB v0.5 starter city notices.
-- Import after lotb_v05.sql.

INSERT IGNORE INTO `lotb_city_services_feed`
(`feed_key`,`category`,`title`,`body`,`district`,`priority`,`expires_at`) VALUES
('WELCOME-LOTB','community','Welcome to Land of the Bloody RP','This city remembers what people do. Use /cityapp to see city services, notices, history, property, work, insurance and more.','citywide',5,DATE_ADD(NOW(),INTERVAL 30 DAY)),
('CIVIC-WORK','services','Neighborhood work board is active','Public work changes based on neighborhood conditions. Use /civicwork when you want legitimate work that actually affects the city.','citywide',2,DATE_ADD(NOW(),INTERVAL 30 DAY));
