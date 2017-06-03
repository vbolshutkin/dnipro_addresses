create table osm_streets as select distinct tags->'name' as name, tags->'name:ru' as name_ru, tags->'name:en' as name_en, tags->'old_name' as old_name from relations WHERE tags->'type' = 'associatedStreet' union select distinct tags->'name', tags->'name:ru' as name_ru, tags->'name:en' as name_en, tags->'old_name' as old_name from ways where tags?'highway';

-- таблица районов 

create table districts as
select name, way as pgn from planet_osm_polygon where admin_level='7';

-- Подготовка данных


update rename set old_name = replace(old_name,' (Таромське)', '') where old_name like '% (Таромське)%';
update rename set district = CONCAT(district, ' район');
update rename set name = 'Січеславська Набережна вулиця' where name like 'Січеславська Набережна набережна' or name like 'Січеславська набережна набережна';
insert into rename(district, old_name, name) values('Центральний район', 'Леніна площа', 'Героїв Майдану площа');


-- ошибки в openaddress (275 повторояющихся адресов)
create table openaddr_dup as select d3.* from (select street, number, name, count(distinct hash), count(distinct name), count(*) from (select hash, street, number, st_makepoint(lon, lat) pt, d.name from openaddr oa join districts d on st_intersects(st_geometryfromtext(CONCAT('POINT(', lon,' ',lat,')'),4326), d.pgn) WHERE number is not null and street is not null) d group by street, number, name having count(*) > 1) d2 JOIN (select hash, street, number, st_makepoint(lon, lat) pt, d.name from openaddr oa join districts d on st_intersects(st_geometryfromtext(CONCAT('POINT(', lon,' ',lat,')'),4326), d.pgn) WHERE number is not null and street is not null) d3 ON d3.street=d2.street and d2.number=d3.number and d2.name=d3.name;

insert into openaddr_dup select hash, street, number, st_geometryfromtext(CONCAT('POINT(', lon,' ',lat,')'),4326) as pt, 'Чечелівський район' from openaddr where street = 'Вахрушева вулиця' and (number = '6' or number = '7');

-- дубликаты улиц в городе (один адрес, разные районы) (110?)
create table openaddr_dupstreets_city as select distinct street from (select street, number, count(distinct hash), count(distinct name), count(*) from (select oa.hash, oa.street, oa.number, st_makepoint(oa.lon, oa.lat) pt, d.name from openaddr oa left join openaddr_dup oad on oad.hash = oa.hash join districts d on st_intersects(st_geometryfromtext(CONCAT('POINT(', lon,' ',lat,')'),4326), d.pgn) WHERE oa.number is not null and oa.street is not null and oad.hash is null) d group by street, number having count(distinct name) > 1) d;

-- улицы-дубликаты пересекающие границы районов
select oa.street, string_agg(distinct d.name, ',' order by d.name) from openaddr oa join openaddr_dupstreets_city od on od.street=oa.street left join openaddr_dup oad on oad.hash = oa.hash join districts d on st_intersects(st_geometryfromtext(CONCAT('POINT(', lon,' ',lat,')'),4326), d.pgn) WHERE oa.number is not null and oa.street is not null and oad.hash is null GROUP by oa.street having count(distinct d.name) > 2;

-- вторичные районы для улиц дубликатов (TODO сделать автоматом для всех)
create table custom_street_districts as
select 'Дарвіна вулиця' as street, 'Центральний район' as district_sec, 'Шевченківський район' as district_ref union all
select 'Димитрова Георгія вулиця' as street, 'Шевченківський район' as district_sec, 'Центральний район' as district_ref union all
select 'Залізнична вулиця' as street, 'Чечелівський район' as district_sec, 'Новокодацький район' as district_ref union all
select 'Комсомольська вулиця' as street, 'Центральний район' as district_sec, 'Шевченківський район' as district_ref union all
select 'Леніна вулиця' as street, 'Центральний район' as district_sec, 'Шевченківський район' as district_ref union all
select 'Промислова вулиця' as street, 'Чечелівський район' as district_sec, 'Новокодацький район' as district_ref union all
select 'Сєрова вулиця' as street, 'Центральний район' as district_sec, 'Шевченківський район' as district_ref union all
select 'Тельмана вулиця' as street, 'Центральний район' as district_sec, 'Шевченківський район' as district_ref union all
select 'Шевченка вулиця' as street, 'Шевченківський район' as district_sec, 'Соборний район' as district_ref union all
select 'Шмідта вулиця' as street, 'Чечелівський район' as district_sec, 'Центральний район' as district_ref;


create table openaddr_by_districts as select oa.street, oa.number, oa.lat, oa.lon, 
CASE WHEN odc.street is NULL THEN NULL ELSE coalesce(csd.district_ref, d.name) END as district from openaddr oa left join openaddr_dupstreets_city odc on odc.street=oa.street left join openaddr_dup oad on oad.hash = oa.hash join districts d on st_intersects(st_geometryfromtext(CONCAT('POINT(', lon,' ',lat,')'),4326), d.pgn) left join custom_street_districts csd on csd.street=oa.street and csd.district_sec = d.name WHERE oa.number is not null and oa.street is not null and oad.hash is null;



---- Сведение улиц (переименования и openaddr)
create table openaddr_rename(district varchar(64), ref_name varchar(64), new_name varchar(64), oa_name varchar(64), old_name varchar(64), osm_name varchar(64));

insert into openaddr_rename(district, ref_name, new_name, oa_name, old_name) select os.district, rs.name, rs.name, rs.old_name, rs.old_name from rename rs join (select street, district from openaddr_by_districts group by district, street) os on rs.old_name=os.street and (rs.district=os.district or os.district is null);

insert into openaddr_rename(district, ref_name, new_name, oa_name, old_name) select os.district, rs.name, rs.name, os.street, rs.old_name from rename rs left join (select street, district from openaddr_by_districts group by district, street) os on levenshtein(rs.old_name,os.street) = 1 left join openaddr_rename oren on oren.old_name=rs.old_name and (oren.district=os.district or oren.district is null) where os.street IS not NULL and oren.ref_name is null and rs.old_name <> 'Сєрова вулиця' and (rs.district=os.district or os.district is null);

insert into openaddr_rename(district, ref_name, new_name, oa_name, old_name) select os.district, rs.name, rs.name, os.street, rs.old_name from rename rs left join (select street, district from openaddr_by_districts group by district, street) os on levenshtein(rs.old_name,os.street) = 2 left join openaddr_rename oren on oren.old_name=rs.old_name and (oren.district=os.district or oren.district is null) where os.street IS not NULL and oren.ref_name is null and rs.old_name <> 'Галана вулиця' AND rs.old_name <> 'Лебедя вулиця' 
 and (rs.district=os.district or os.district is null);

-- ручной маппинг

create table custom_mapping as
select '' as old_name, '' as oa_name union all
select 'Варейкіса вулиця', '' union all
select 'Галана вулиця', 'Галана Ярослава вулиця' union all
select 'Героїв Громадянської війни вулиця', '' union all
select 'ім. газети ''Правда'' проспект', 'Газети Правда проспект' union all
select 'Івана Зінукова вулиця', 'Зінукова Івана вулиця' union all
select 'Івана Зінукова провулок', 'Зінукова провулок' union all
select 'Лебедя вулиця', '' union all
select 'Леоніда Брежнєва вулиця', 'Брежнєва Леоніда вулиця' union all
select 'Лепсе вулиця', 'Лепсе Івана вулиця' union all
select 'Людміли Мокієвської вулиця', 'Мокієвської Людміли вулиця' union all
select 'Моріса Тореза вулиця', 'Тореза Моріса вулиця' union all
select 'Набережна Чудновського', '' union all
select 'Пелагеї Поляхової вулиця', 'Поляхової Пелагеї вулиця' union all
select 'Сиворонова провулок', '' union all
select '40 років комсомолу провулок', '' union all
select 'Дибенка провулок', 'Дибенка Павла провулок' union all
select 'Дибенка вулиця', 'Дибенка Павла вулиця' union all
select 'Димитрова вулиця', 'Димитрова Георгія вулиця' union all
select 'Карла Лібкнехта вулиця', 'Лібкнехта Карла вулиця' union all
select 'ім. В.І. Леніна набережна', 'Леніна Набережна вулиця' union all
select 'Петра Моїсеєнка вулиця', 'Моісеєнка Петра вулиця' union all
select 'Дем’яна Бєдного площа', 'Бєдного Дем''яна площа' union all
select 'Дмитра Донського вулиця', 'Донського Дмитра вулиця' union all
select 'Клари Цеткін вулиця', 'Цеткін Клари вулиця' union all
select 'Колгоспний провулок', '' union all
select 'Коцюбинського вулиця', 'Коцюбинського Михайла вулиця' union all
select 'ім. В.І. Леніна набережна', 'Леніна Набережна вулиця' union all
select 'Рози Люксембург вулиця', 'Люксембург Рози вулиця' union all
select 'Тупик Червоної балки провулок', 'Червона Балка тупик' union all
select 'Фучіка вулиця', 'Фучіка Юліуса вулиця' union all
select 'ім. Газети Правда проспект', 'Газети Правда проспект' union all
select 'XXII партз’зду вулиця', 'XXII Партз''їзду вулиця' union all
select '80-річчя Дніпропетровської області площа', '' union all
select 'Горького вулиця', 'Горького Максима вулиця' union all
select 'Горького площа', 'Горького Максима площа' union all
select 'Димитрова вулиця', 'Димитрова Георгія вулиця' union all
select 'Ілліча вулиця', '' union all
select 'Миколи Островського площа', 'Островського Миколи площа' union all
select 'набережна ім. В.І. Леніна', 'Леніна Набережна вулиця' union all
select 'Сергія Лазо вулиця', 'Лазо Сергія вулиця' union all
select 'Щербицького вулиця', '' union all
select 'Балка колгоспна вулиця', 'Колгоспна Балка вулиця' union all
select 'Інтернаціональний провулок', '' union all
select 'Марини Раскової вулиця', 'Раскової Марини вулиця' union all
select 'Профінтерну вулиця', '' union all
select '80-річчя Дніпропетровщини вулиця', '' union all
select 'Власенка вулиця', '' union all
select 'Войцеховський провулок', '' union all
select 'Володимира Ошка вулиця', 'Ошка Володимира вулиця' union all
select 'Дибенка вулиця', 'Дибенка Павла вулиця' union all
select 'Димитрова вулиця', 'Димитрова Георгія вулиця' union all
select 'Івана Сусаніна вулиця', 'Сусаніна Івана вулиця' union all
select 'Івана Сусаніна провулок', 'Сусаніна Івана провулок' union all
select 'Красіна провулок', '' union all
select 'Людмили Сталь провулок', 'Сталь Людмили провулок' union all
select 'Митрофана Андреєва вулиця', 'Андреєва Митрофана вулиця' union all
select 'Павла Корчагіна вулиця', 'Корчагіна Павла вулиця' union all
select 'Петра Сиротиніна вулиця', 'Сиротиніна Петра вулиця' union all
select 'Покровського провулок', '' union all
select 'Тихона Бондарева вулиця', 'Бондарева Тихона вулиця' union all
select 'Хуліана Грімау вулиця', 'Грімау Хуліана вулиця' union all
select 'Барбюса вулиця', 'Барбюса Анрі вулиця' union all
select 'Галана вулиця', 'Галана Ярослава вулиця' union all
select 'Дундича вулиця', '' union all
select 'Червонопролетарський провулок', '';

insert into openaddr_rename(district, ref_name, new_name, oa_name, old_name) select distinct os.district, rs.name, rs.name, os.street, rs.old_name from rename rs  left join custom_mapping cm on cm.old_name = rs.old_name left join (select street, district from openaddr_by_districts group by district, street) os on os.street=cm.oa_name left join openaddr_rename oren on oren.old_name=rs.old_name and (oren.district=os.district or oren.district is null) where os.street IS not NULL and oren.ref_name is null;

-- переименования, которым не нашлось прямого совпадения в базе адресов
insert into openaddr_rename(ref_name, new_name, oa_name, old_name) select rs.name, rs.name, null, rs.old_name from rename rs left join openaddr_rename oren on oren.old_name=rs.old_name where oren.ref_name is null;




-- обновлённые данные для openaddr (с учётом переименований, с выкинутыми дубликатами)
create table openaddr_updated as
select coalesce(oren.ref_name, od.street) as street, od.number, od.lat, od.lon, od.district from openaddr_by_districts od left join openaddr_rename oren on oren.oa_name = od.street and (oren.district is null or oren.district = od.district) order by od.street, od.district;

-- список улиц с именами
create table streets_final as select oas.street as street, oas.street as name, os.name_ru, os.name_en, coalesce(r.old_name, os.old_name) old_name from (select distinct street from openaddr_updated) oas left join osm_streets os on oas.street=os.name left join rename r on os.name=r.name order by name;


