const csvFilePath='openaddr_upd.csv'
const streetsCsvFilePath='streets_final.csv'
const csv=require('csvtojson')
var fs = require("fs");

var streets = {};
var addrs = {};

csv()
.fromFile(streetsCsvFilePath)
.preRawData((csvRawData,cb)=>{
    if (csvRawData.charCodeAt(0) > 2000) console.log("!!!!!!", csvRawData.substring(0, 10));
    cb(csvRawData);
})
.on('json',(jsonObj)=>{
  if (!jsonObj.name_ru) delete jsonObj.name_ru;
  if (!jsonObj.name_en) delete jsonObj.name_en;
  if (!jsonObj.old_name) delete jsonObj.old_name;
  streets[jsonObj.street] = jsonObj;
  delete streets[jsonObj.street].street;
}).on('done',(error)=>{
	csv()
	.preRawData((csvRawData,cb)=>{
	    if (csvRawData.charCodeAt(0) > 2000) console.log("!!!!!!", csvRawData.substring(0, 10));
	    cb(csvRawData);
	})
	.fromFile(csvFilePath)
	.on('json',(jsonObj)=>{
            //console.log(jsonObj);
	    // combine csv header row and csv line to a json object 
	    // jsonObj.a ==> 1 or 4 
	    var str = jsonObj.street;
            if (!str) return;
            if (!streets[str]) return;

            if (str != streets[str].name && str.indexOf("енін") > -1) console.log(str, streets[str].name, streets[str].old_name);

	    // workaround for https://github.com/Keyang/node-csvtojson/issues/175
	    jsonObj.district = jsonObj.district.replace('��', 'а');

            if (str.indexOf("Орловська") > -1 && jsonObj.number==25) console.log(jsonObj);
            var key = streets[str].name + (jsonObj.district ?  " (" + jsonObj.district + ")" : "");
	    if (!addrs[key]) addrs[key] = {alt: JSON.parse(JSON.stringify(streets[str])), h: {}};
	    if (jsonObj.district) {
		addrs[key].alt['district'] = jsonObj.district;
	    }
	    addrs[key].h[jsonObj.number] = [+jsonObj.lat, +jsonObj.lon];
	})
	.on('done',(error)=>{
	    fs.writeFileSync("addrs.js", "addrs = " + JSON.stringify(addrs, null, 2) + ";", "utf8");
	}) 
}) 



