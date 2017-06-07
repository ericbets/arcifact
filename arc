#!/usr/bin/env node
var fs = require('fs');
var os = require('os');
var sqlite3 = require('sqlite3').verbose();
var yargs = require('yargs')
var Nightmare = require("nightmare");
var shelljs = require('shelljs');
var pathResolve = require('path').resolve;
var prettyHtml = require('html');
var cwd = shelljs.pwd();
var dbFile = ".arcifact/arcifact.sqlite";

Nightmare.action('getDom', function(done) {
  //`this` is the Nightmare instance
  this.evaluate_now(() => {
	if (document.doctype!=null)
		return document.doctype + "\n" + document.documentElement.outerHTML;
	else
		return document.documentElement.outerHTML;
  }, done)
});

function newline() {
	return String.fromCharCode(13);
}

function abspath(path, file) {
	return pathResolve(path + "/" + file);
}

function beautify(txt) {
	var pretty = prettyHtml.prettyPrint(txt);
	//console.log(pretty);
	return pretty;
}

class NightmareControl {
	constructor() {
		this.nightmare = Nightmare({show:false});			
	}
	monolith(obj) {
		fs.writeFile(abspath(cwd,"monolith.js"),"var arcdata =" + JSON.stringify(obj) + ";\n",function(err) {
				if(err) return console.log(err);
		});	
	}
	patch(json, inFile, outFile, isGlobal) {
		if (isGlobal) {
			this.nightmare.goto("file://" + inFile).evaluate(function() {
				var script = document.createElement("script");
				script.setAttribute("data-arc-gen","");
				script.setAttribute("src","monolith.js");
				document.head.appendChild(script);
			}).getDom().then((dom) => {
				fs.writeFileSync(outFile, dom); 
				fs.writeFileSync("monolith.js", json); 
			}).then(this.nightmare.end()).catch((e) => console.dir(e));	
		}
		else {
			this.nightmare.goto("file://" + inFile).evaluate(function(json) {
				var script = document.createElement("script");
				script.setAttribute("data-arc-gen","");

				script.innerHTML = json;
				document.head.appendChild(script);
			},json).getDom().then((dom) => {
				fs.writeFileSync(outFile, beautify(dom) + "\n"); 
			}).then(this.nightmare.end()).catch((e) => console.dir(e));	
		}
	}
	unpatch(inFile, outFile) {
			this.nightmare.goto("file://" + inFile).evaluate(function() {
			        var ascripts = document.getElementsByTagName("script");
				var list = [];
			        for (var i=0; i<ascripts.length;i++) { 
					if (ascripts[i]!==null && typeof(ascripts[i])!=='undefined')
				            if (ascripts[i].getAttribute("data-arc-gen")==="")
						list.push(ascripts[i]);
        			}	
				list.forEach((node) => {
					node.parentNode.removeChild(node);
				});
			}).getDom().then((dom) => {
				fs.writeFileSync(outFile, beautify(dom) + "\n");
			}).then(this.nightmare.end()).catch((e) => console.dir(e));	
	}
	render(inFile,outFile) {
			this.nightmare.goto("file://" + inFile).evaluate(function() {
			        var ascripts = document.getElementsByTagName("script");
 				var list = [];	
			        for (var i=0; i<ascripts.length;i++) {				    	 
			            if (ascripts[i].getAttribute("data-arc-custom")==="") {
					list.push(ascripts[i]);
				    }
				    else if (ascripts[i].getAttribute("data-arc-gen")==="") {
					list.push(ascripts[i]);
				    }
        			}	
				list.forEach((node) => {
					node.parentNode.removeChild(node);
				});
			}).getDom().then((dom) => {
				fs.writeFileSync(outFile, beautify(dom) + "\n") 
			}).then(this.nightmare.end()).catch((e) => console.dir(e));	
	}
}

var argv = yargs.usage('usage: $0 <cmd>')
	.command('init', 'Create an empty arcifact repository', function (yargs) {
		init();
	})
	.command('add', '<file> <msg> Add file into the arcifact repository', function (yargs) {
		var file = yargs.argv["_"][1];
		var msg = yargs.argv["_"][2];
		add(file,msg);
	 })
	.command('rm', '<file> Remove file from the arcifact repository', function (yargs) {
		var file = yargs.argv["_"][1];
		rm(file);
	})
	.command('put', '<category> <file> <key> <value> Store data about a file', function (yargs) {
		var category = yargs.argv["_"][1];
		var file = yargs.argv["_"][2];
		var key = yargs.argv["_"][3];
		var value = yargs.argv["_"][4];
		put(category,file,key,value);
	})
	.command('ipatch', '<file> Inline patch an html file', function (yargs) {
		var file = yargs.argv["_"][1];
		patch(file,false);
	})
	.command('gpatch', '<file> Global patch an html file', function (yargs) {
		var file = yargs.argv["_"][1];
		patch(file, true);
	}) 	
	.command('unpatch', '<file> Unpatch the html', function (yargs) {
		var file = yargs.argv["_"][1];
		unpatch(file);	
	})
	.command('render','<indir> <outdir> Render the project', function (yargs) {
		var indir = yargs.argv["_"][1];
		var outdir = yargs.argv["_"][2];
		render(indir,outdir);
	})
	.command('status', 'Show the status of your arcifact repository', function (yargs) {
		status();
	})
	.command('version','Show the arcifact version',function (yargs) {
		version();
	})
	.help('help').wrap(null).argv;

function version() {
	console.log("Arcifact v1.0");
}

  /**
   * @param {string} indir - Input folder
   * @param {string} outdir - Output folder
   */
function render(indir,outdir) {
	shelljs.mkdir(outdir);

	shelljs.ls(indir).forEach(function(file) {
		if (file.endsWith(".html")) {
			var infile = pathResolve(indir + "/" + file);
			var outfile = pathResolve(outdir + "/" + file);
			var nm = new NightmareControl();
			nm.render(infile,outfile);
		}
		else {
			shelljs.cp(file,outdir);
		}		

	});
}

function init() {
	shelljs.mkdir("-p", ".arcifact");
	var db = new sqlite3.Database(dbFile);
	db.serialize(function() {
		  db.run("CREATE TABLE arckv(category TEXT, filename TEXT, key TEXT, value TEXT, PRIMARY KEY (category,filename,key))");
	});
	db.close();
}

  /**
   * @param {string} file - Html file to unpatch
   */
function unpatch(file) {
	var nm = new NightmareControl();
	nm.unpatch(abspath(cwd,file),abspath(cwd,file));
}

function put(category,filename,key,value) {
	var db = new sqlite3.Database(dbFile);
	db.serialize(function() {
		var stmt = db.prepare("INSERT INTO arckv (category,filename,key,value) VALUES (?,?,?,?)");
		stmt.run(category,filename,key,value);
		stmt.finalize();
	});
	db.close();
}
 
 /**
   * @param {string} file - Html file to patch with db contents
   * @param {boolean} isGlobal - false adds the contents inline, true puts them into a file named monolith.js
   */
function patch(file,isGlobal) {
	var db = new sqlite3.Database(dbFile);

	db.all("SELECT * FROM arckv", function(err,rows) {			
		if (err) {
			console.log("Error");
		}
		else {
			var arcRoot = {};
			arcRoot["rows"] = rows;
			var json = "var arc=" + JSON.stringify(arcRoot) + ";\n"
			var luggageDir = os.homedir() + "/" + ".arcifact/luggage.js";
			if (fs.existsSync(luggageDir)) {
				json += fs.readFileSync(luggageDir,'utf8'); 
			}
			var old = ";function scan(key, val) { var list = []; for (var i=0; i<arc['rows'].length;i++) { if (arc['rows'][i][key]===val) { list.push(arc['rows'][i]); } } return list; }; function scan2(key, val,key2,val2) { var list = []; for (var i=0; i<arc['rows'].length;i++) { if (arc['rows'][i][key]===val && arc['rows'][i][key2]==val2) { list.push(arc['rows'][i]); } } return list; };function scan3(key, val,key2,val2,key3,val3) { var list = []; for (var i=0; i<arc['rows'].length;i++) { if (arc['rows'][i][key]===val && arc['rows'][i][key2]==val2 && arc['rows'][i][key3]==val3) { list.push(arc['rows'][i]); } } return list; } ";
			var nm = new NightmareControl();
			if (isGlobal) 
				nm.patch(json, abspath(cwd,file),abspath(cwd,file), true);
			else
				nm.patch(json, abspath(cwd,file),abspath(cwd,file), false);			
		}
    	});
}
  /**
   * @param {string} file - File to be tracked by the database 
   * @param {string} msg - Description of the file
   */

function add(file,msg) {
	put("default",file,"description",msg);
}
  /**
   * @param {string} file - File to be removed from the database description table
   */
function rm(file) {
	var db = new sqlite3.Database(dbFile);
	db.serialize(function() {
		var stmt = db.prepare("DELETE FROM arckv WHERE filename=?");
		stmt.run(file);
		stmt.finalize();
	});
	db.close()
}

function status() {
	var db = new sqlite3.Database(dbFile);
	db.serialize(function() {
		db.each("SELECT * FROM arckv", function(err,row) {
			console.log("  " + row.category + " " + row.filename + " " + row.key + " " + row.value);
		});
	});
	db.close();
}



