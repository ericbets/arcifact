Arcifact
===================

Arcifact is a simple tool to record metadata about files for publishing on the web. Also a static site generator lightly modelled in interface after the git dvcs. Influenced by mustache.js, metalsmith, hexo, git & others. It shows it's strength when you have a selection of existing templates to try on, as you would a coat, scarf or other classical accroutrement. 

Awhile back, I read an offhand comment by the author of ANTLR, Terrence Parr. He said, if you are using templates, you shouldn't have any logic or conditionals inside the template. His reasoning was because if you do otherwise, the template is no longer a template, it's *software*. So you are better off just writing your software the way you usually write it. This was influential to me at the time and this tool has descended from that line of thinking. Your templates are standard html files.

Commands
--------
```shell
usage: arc <cmd> 

Commands:
  init     Create an empty arcifact repository
  add      <file> <msg> Add file into the arcifact repository
  rm       <file> Remove file from the arcifact repository
  put      <category> <file> <key> <value> Store data about a file
  ipatch   <file> Inline patch an html file
  gpatch   <file> Global patch an html file
  unpatch  <file> Unpatch the html
  render   <indir> <outdir> Render the project
  status   Show the status of your arcifact repository
  version  Show the arcifact version
```

Intended Workflow
-------
1. Make a webpage
2. Get some data, store it in files or using arcifact.
3. Query the data and plug it into the page eg.
```js 
$("post-date") = lookup("blog-posts","my-essay.txt","post-date");`
```

Example
------
```shell
arc init
```
This creates a project. Similiar to git, this creates an sqlite db in .arcifact/arcifact.sqlite

```shell
echo '<html><head></head><body><img src="sea-turtle.jpg"><p id='caption'></p></body></html>' > page.html
arc add turtle.jpg "This is a picture of an extinct sea turtle."
```

This will put the contents of your sqlite database inside your webpage as a javascript object.
```shell
arc ipatch page.html
```

Modify your webpage to make it look however you want it. eg.

```shell
echo '<script data-arc-custom>$("#caption").innerText = lookup("default","turtle.jpg","description");</script>' >> page.html
```

If you are using my luggage.js file with the lookup function (see below), this will query your data.

```shell
arc render ../proj build/
```
For each html file in the project, a headless browser is run, that reads the webpage, removes any javascript marked with *data-arc-custom* or *data-arc-gen* and saves the output of the webpages in the output directory.

Magic Tags
------------------

Arcifact relies on two magic words in your htmls script tag attributes to do it's thing. 

```html
<script data-arc-gen></script>
```
When an html file is patched, all data from your sqlite database is put into a script tag inside the head tag of your project with the data-arc-gen attribute.

```html
<script data-arc-custom></script>
```
When a webpage is rendered, it's javascript will be executed. Of the two magic attributes. *data-arc-gen* code can be removed by using the unpatch command, since it's still in your sqlite database. Any code put in a script tag marked *data-arc-custom* is never deleted from your source copy, but will be removed from the **rendered** copy. 

Luggage
------------
If you have a file called ~/.arcifact/luggage.js inside your $HOME directory, it will get included in the patch operation. For example:
```js
$ = (selector) => document.querySelector(selector);
            
function scan(key, val) { var list = []; for (var i=0; i<arc['rows'].length;i++) { if (arc['rows'][i][key]===val) { list.push(arc['rows'][i]); } } return list; }; 
            
function scan2(key, val,key2,val2) { var list = []; for (var i=0; i<arc['rows'].length;i++) { if (arc['rows'][i][key]===val && arc['rows'][i][key2]==val2) { list.push(arc['rows'][i]); } } return list; };
            
function lookup(category,filename,key) { for (var i=0; i<arc['rows'].length;i++) { if (arc['rows'][i]["category"]===category && arc['rows'][i]["filename"]===filename && arc['rows'][i]["key"]===key) { return arc['rows'][i]["value"]; } } }


