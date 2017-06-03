drop database if exists dnipro_addresses;
create database dnipro_addresses;
\c dnipro_addresses;
create extension PostGis;
create extension hstore;
create extension fuzzystrmatch;

create table rename(district varchar(64), old_name varchar(64), name varchar(64));
create table openaddr(lon double precision, lat double precision, number varchar(64), street varchar(64), unit varchar(64), city varchar(64), district varchar(64), region varchar(64), postcode varchar(64), id varchar(64), hash varchar(64));



