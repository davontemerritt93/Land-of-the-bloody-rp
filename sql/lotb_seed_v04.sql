-- Optional LOTB v0.4 starter content.
-- Import after lotb_v04.sql for a quick smoke-test dealership.

INSERT IGNORE INTO `lotb_dealership_inventory`
(`stock_key`,`dealership_key`,`model`,`label`,`price`,`quantity`,`garage`,`metadata_json`) VALUES
('city_blista','city_motors','blista','Blista',18000,4,'pillboxgarage','{}'),
('city_sultan','city_motors','sultan','Sultan',48000,3,'pillboxgarage','{}'),
('city_granger','city_motors','granger','Granger',62000,2,'pillboxgarage','{}');
