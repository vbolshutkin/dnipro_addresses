var fs = require("fs");

var json = JSON.parse(fs.readFileSync("rename.json"));

var csv = "district,old_name,name\n";

function getTypeStr(type) {
    switch (type) {
	case 'street': return " вулиця";
	case 'lane': return " провулок";
	case 'avenue': return " проспект";
	case 'slope': return " узвіз";
	case 'impasse': return " тупік";
	case 'embankment': return " набережна";
	case 'square': return " площа"; // XXX іноді майдан
	default:
          console.log('skipping', type); 
          return "";
    }
}

function appendIf(name, typeStr) {
        name = name.replace(" (Таромське)", "");
	//if ((" "+name).toUpperCase().indexOf(typeStr.toUpperCase()) > -1) return name;
        return name + typeStr;
}

for (rev in json) {
  if (rev == "lastUpdated") continue;
  for (k in json[rev].objects) {
    var v = json[rev].objects[k];
    
    if (!getTypeStr(v['type'])) continue;

    csv += json[rev].newAreaName + "," + appendIf(v['oldName'],getTypeStr(v['type'])) + "," + appendIf(v['newName'], getTypeStr(v['newType'] || v['type'])) + "\n"
  }
}

fs.writeFile("rename.csv", csv, "utf8");
