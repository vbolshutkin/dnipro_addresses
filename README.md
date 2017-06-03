This project contains linux script that downloads data from OSM, OpenAddresses and renamings in Dnipro to populate address database usable for search with Leaflet (I use Fuse.js here).

1. run `bash process.sh`
2. open `dnipro_addr_search.html` 

Known issues:
1. the OSM map itself can miss some house numbers present in OpenAddresses, so you can find a house using search, zoom into it and see no number
2. OpenAddresses can point not exactly to house, error might raise 50 m
3. The OSM map itself contains ~25 streets that are not renamed, so you can encounter some old name at the map layer (but not in search)
4. The address database produced as a single json file 5.8 Mb, not suitable for mobile.

Ideas for future:
1. Try to sync OSM with openaddresses. This is usually done manually https://osm.splashthat.com/ https://youtu.be/8QJNjmn3o7I. But I dream about automating that.
2. decompose Fuzzy address search as a separate project. Nominatim is not fuzzy enough, but it also can be patched
