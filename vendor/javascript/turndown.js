// turndown@7.2.0 downloaded from https://ga.jspm.io/npm:turndown@7.2.0/lib/turndown.browser.es.js

function extend(e){for(var n=1;n<arguments.length;n++){var t=arguments[n];for(var r in t)t.hasOwnProperty(r)&&(e[r]=t[r])}return e}function repeat(e,n){return Array(n+1).join(e)}function trimLeadingNewlines(e){return e.replace(/^\n*/,"")}function trimTrailingNewlines(e){var n=e.length;while(n>0&&e[n-1]==="\n")n--;return e.substring(0,n)}var e=["ADDRESS","ARTICLE","ASIDE","AUDIO","BLOCKQUOTE","BODY","CANVAS","CENTER","DD","DIR","DIV","DL","DT","FIELDSET","FIGCAPTION","FIGURE","FOOTER","FORM","FRAMESET","H1","H2","H3","H4","H5","H6","HEADER","HGROUP","HR","HTML","ISINDEX","LI","MAIN","MENU","NAV","NOFRAMES","NOSCRIPT","OL","OUTPUT","P","PRE","SECTION","TABLE","TBODY","TD","TFOOT","TH","THEAD","TR","UL"];function isBlock(n){return is(n,e)}var n=["AREA","BASE","BR","COL","COMMAND","EMBED","HR","IMG","INPUT","KEYGEN","LINK","META","PARAM","SOURCE","TRACK","WBR"];function isVoid(e){return is(e,n)}function hasVoid(e){return has(e,n)}var t=["A","TABLE","THEAD","TBODY","TFOOT","TH","TD","IFRAME","SCRIPT","AUDIO","VIDEO"];function isMeaningfulWhenBlank(e){return is(e,t)}function hasMeaningfulWhenBlank(e){return has(e,t)}function is(e,n){return n.indexOf(e.nodeName)>=0}function has(e,n){return e.getElementsByTagName&&n.some((function(n){return e.getElementsByTagName(n).length}))}var r={};r.paragraph={filter:"p",replacement:function(e){return"\n\n"+e+"\n\n"}};r.lineBreak={filter:"br",replacement:function(e,n,t){return t.br+"\n"}};r.heading={filter:["h1","h2","h3","h4","h5","h6"],replacement:function(e,n,t){var r=Number(n.nodeName.charAt(1));if(t.headingStyle==="setext"&&r<3){var i=repeat(r===1?"=":"-",e.length);return"\n\n"+e+"\n"+i+"\n\n"}return"\n\n"+repeat("#",r)+" "+e+"\n\n"}};r.blockquote={filter:"blockquote",replacement:function(e){e=e.replace(/^\n+|\n+$/g,"");e=e.replace(/^/gm,"> ");return"\n\n"+e+"\n\n"}};r.list={filter:["ul","ol"],replacement:function(e,n){var t=n.parentNode;return t.nodeName==="LI"&&t.lastElementChild===n?"\n"+e:"\n\n"+e+"\n\n"}};r.listItem={filter:"li",replacement:function(e,n,t){e=e.replace(/^\n+/,"").replace(/\n+$/,"\n").replace(/\n/gm,"\n    ");var r=t.bulletListMarker+"   ";var i=n.parentNode;if(i.nodeName==="OL"){var a=i.getAttribute("start");var o=Array.prototype.indexOf.call(i.children,n);r=(a?Number(a)+o:o+1)+".  "}return r+e+(n.nextSibling&&!/\n$/.test(e)?"\n":"")}};r.indentedCodeBlock={filter:function(e,n){return n.codeBlockStyle==="indented"&&e.nodeName==="PRE"&&e.firstChild&&e.firstChild.nodeName==="CODE"},replacement:function(e,n,t){return"\n\n    "+n.firstChild.textContent.replace(/\n/g,"\n    ")+"\n\n"}};r.fencedCodeBlock={filter:function(e,n){return n.codeBlockStyle==="fenced"&&e.nodeName==="PRE"&&e.firstChild&&e.firstChild.nodeName==="CODE"},replacement:function(e,n,t){var r=n.firstChild.getAttribute("class")||"";var i=(r.match(/language-(\S+)/)||[null,""])[1];var a=n.firstChild.textContent;var o=t.fence.charAt(0);var l=3;var u=new RegExp("^"+o+"{3,}","gm");var s;while(s=u.exec(a))s[0].length>=l&&(l=s[0].length+1);var c=repeat(o,l);return"\n\n"+c+i+"\n"+a.replace(/\n$/,"")+"\n"+c+"\n\n"}};r.horizontalRule={filter:"hr",replacement:function(e,n,t){return"\n\n"+t.hr+"\n\n"}};r.inlineLink={filter:function(e,n){return n.linkStyle==="inlined"&&e.nodeName==="A"&&e.getAttribute("href")},replacement:function(e,n){var t=n.getAttribute("href");t&&(t=t.replace(/([()])/g,"\\$1"));var r=cleanAttribute(n.getAttribute("title"));r&&(r=' "'+r.replace(/"/g,'\\"')+'"');return"["+e+"]("+t+r+")"}};r.referenceLink={filter:function(e,n){return n.linkStyle==="referenced"&&e.nodeName==="A"&&e.getAttribute("href")},replacement:function(e,n,t){var r=n.getAttribute("href");var i=cleanAttribute(n.getAttribute("title"));i&&(i=' "'+i+'"');var a;var o;switch(t.linkReferenceStyle){case"collapsed":a="["+e+"][]";o="["+e+"]: "+r+i;break;case"shortcut":a="["+e+"]";o="["+e+"]: "+r+i;break;default:var l=this.references.length+1;a="["+e+"]["+l+"]";o="["+l+"]: "+r+i}this.references.push(o);return a},references:[],append:function(e){var n="";if(this.references.length){n="\n\n"+this.references.join("\n")+"\n\n";this.references=[]}return n}};r.emphasis={filter:["em","i"],replacement:function(e,n,t){return e.trim()?t.emDelimiter+e+t.emDelimiter:""}};r.strong={filter:["strong","b"],replacement:function(e,n,t){return e.trim()?t.strongDelimiter+e+t.strongDelimiter:""}};r.code={filter:function(e){var n=e.previousSibling||e.nextSibling;var t=e.parentNode.nodeName==="PRE"&&!n;return e.nodeName==="CODE"&&!t},replacement:function(e){if(!e)return"";e=e.replace(/\r?\n|\r/g," ");var n=/^`|^ .*?[^ ].* $|`$/.test(e)?" ":"";var t="`";var r=e.match(/`+/gm)||[];while(r.indexOf(t)!==-1)t+="`";return t+n+e+n+t}};r.image={filter:"img",replacement:function(e,n){var t=cleanAttribute(n.getAttribute("alt"));var r=n.getAttribute("src")||"";var i=cleanAttribute(n.getAttribute("title"));var a=i?' "'+i+'"':"";return r?"!["+t+"]("+r+a+")":""}};function cleanAttribute(e){return e?e.replace(/(\n+\s*)+/g,"\n"):""}function Rules(e){this.options=e;this._keep=[];this._remove=[];this.blankRule={replacement:e.blankReplacement};this.keepReplacement=e.keepReplacement;this.defaultRule={replacement:e.defaultReplacement};this.array=[];for(var n in e.rules)this.array.push(e.rules[n])}Rules.prototype={add:function(e,n){this.array.unshift(n)},keep:function(e){this._keep.unshift({filter:e,replacement:this.keepReplacement})},remove:function(e){this._remove.unshift({filter:e,replacement:function(){return""}})},forNode:function(e){return e.isBlank?this.blankRule:(n=findRule(this.array,e,this.options))||(n=findRule(this._keep,e,this.options))||(n=findRule(this._remove,e,this.options))?n:this.defaultRule;var n},forEach:function(e){for(var n=0;n<this.array.length;n++)e(this.array[n],n)}};function findRule(e,n,t){for(var r=0;r<e.length;r++){var i=e[r];if(filterValue(i,n,t))return i}}function filterValue(e,n,t){var r=e.filter;if(typeof r==="string"){if(r===n.nodeName.toLowerCase())return true}else if(Array.isArray(r)){if(r.indexOf(n.nodeName.toLowerCase())>-1)return true}else{if(typeof r!=="function")throw new TypeError("`filter` needs to be a string, array, or function");if(r.call(e,n,t))return true}}
/**
 * collapseWhitespace(options) removes extraneous whitespace from an the given element.
 *
 * @param {Object} options
 */function collapseWhitespace(e){var n=e.element;var t=e.isBlock;var r=e.isVoid;var i=e.isPre||function(e){return e.nodeName==="PRE"};if(n.firstChild&&!i(n)){var a=null;var o=false;var l=null;var u=next(l,n,i);while(u!==n){if(u.nodeType===3||u.nodeType===4){var s=u.data.replace(/[ \r\n\t]+/g," ");a&&!/ $/.test(a.data)||o||s[0]!==" "||(s=s.substr(1));if(!s){u=remove(u);continue}u.data=s;a=u}else{if(u.nodeType!==1){u=remove(u);continue}if(t(u)||u.nodeName==="BR"){a&&(a.data=a.data.replace(/ $/,""));a=null;o=false}else if(r(u)||i(u)){a=null;o=true}else a&&(o=false)}var c=next(l,u,i);l=u;u=c}if(a){a.data=a.data.replace(/ $/,"");a.data||remove(a)}}}
/**
 * remove(node) removes the given node from the DOM and returns the
 * next node in the sequence.
 *
 * @param {Node} node
 * @return {Node} node
 */function remove(e){var n=e.nextSibling||e.parentNode;e.parentNode.removeChild(e);return n}
/**
 * next(prev, current, isPre) returns the next node in the sequence, given the
 * current and previous nodes.
 *
 * @param {Node} prev
 * @param {Node} current
 * @param {Function} isPre
 * @return {Node}
 */function next(e,n,t){return e&&e.parentNode===n||t(n)?n.nextSibling||n.parentNode:n.firstChild||n.nextSibling||n.parentNode}var i=typeof window!=="undefined"?window:{};function canParseHTMLNatively(){var e=i.DOMParser;var n=false;try{(new e).parseFromString("","text/html")&&(n=true)}catch(e){}return n}function createHTMLParser(){var Parser=function(){};shouldUseActiveX()?Parser.prototype.parseFromString=function(e){var n=new window.ActiveXObject("htmlfile");n.designMode="on";n.open();n.write(e);n.close();return n}:Parser.prototype.parseFromString=function(e){var n=document.implementation.createHTMLDocument("");n.open();n.write(e);n.close();return n};return Parser}function shouldUseActiveX(){var e=false;try{document.implementation.createHTMLDocument("").open()}catch(n){i.ActiveXObject&&(e=true)}return e}var a=canParseHTMLNatively()?i.DOMParser:createHTMLParser();function RootNode(e,n){var t;if(typeof e==="string"){var r=htmlParser().parseFromString('<x-turndown id="turndown-root">'+e+"</x-turndown>","text/html");t=r.getElementById("turndown-root")}else t=e.cloneNode(true);collapseWhitespace({element:t,isBlock:isBlock,isVoid:isVoid,isPre:n.preformattedCode?isPreOrCode:null});return t}var o;function htmlParser(){o=o||new a;return o}function isPreOrCode(e){return e.nodeName==="PRE"||e.nodeName==="CODE"}function Node(e,n){e.isBlock=isBlock(e);e.isCode=e.nodeName==="CODE"||e.parentNode.isCode;e.isBlank=isBlank(e);e.flankingWhitespace=flankingWhitespace(e,n);return e}function isBlank(e){return!isVoid(e)&&!isMeaningfulWhenBlank(e)&&/^\s*$/i.test(e.textContent)&&!hasVoid(e)&&!hasMeaningfulWhenBlank(e)}function flankingWhitespace(e,n){if(e.isBlock||n.preformattedCode&&e.isCode)return{leading:"",trailing:""};var t=edgeWhitespace(e.textContent);t.leadingAscii&&isFlankedByWhitespace("left",e,n)&&(t.leading=t.leadingNonAscii);t.trailingAscii&&isFlankedByWhitespace("right",e,n)&&(t.trailing=t.trailingNonAscii);return{leading:t.leading,trailing:t.trailing}}function edgeWhitespace(e){var n=e.match(/^(([ \t\r\n]*)(\s*))(?:(?=\S)[\s\S]*\S)?((\s*?)([ \t\r\n]*))$/);return{leading:n[1],leadingAscii:n[2],leadingNonAscii:n[3],trailing:n[4],trailingNonAscii:n[5],trailingAscii:n[6]}}function isFlankedByWhitespace(e,n,t){var r;var i;var a;if(e==="left"){r=n.previousSibling;i=/ $/}else{r=n.nextSibling;i=/^ /}r&&(r.nodeType===3?a=i.test(r.nodeValue):t.preformattedCode&&r.nodeName==="CODE"?a=false:r.nodeType!==1||isBlock(r)||(a=i.test(r.textContent)));return a}var l=Array.prototype.reduce;var u=[[/\\/g,"\\\\"],[/\*/g,"\\*"],[/^-/g,"\\-"],[/^\+ /g,"\\+ "],[/^(=+)/g,"\\$1"],[/^(#{1,6}) /g,"\\$1 "],[/`/g,"\\`"],[/^~~~/g,"\\~~~"],[/\[/g,"\\["],[/\]/g,"\\]"],[/^>/g,"\\>"],[/_/g,"\\_"],[/^(\d+)\. /g,"$1\\. "]];function TurndownService(e){if(!(this instanceof TurndownService))return new TurndownService(e);var n={rules:r,headingStyle:"setext",hr:"* * *",bulletListMarker:"*",codeBlockStyle:"indented",fence:"```",emDelimiter:"_",strongDelimiter:"**",linkStyle:"inlined",linkReferenceStyle:"full",br:"  ",preformattedCode:false,blankReplacement:function(e,n){return n.isBlock?"\n\n":""},keepReplacement:function(e,n){return n.isBlock?"\n\n"+n.outerHTML+"\n\n":n.outerHTML},defaultReplacement:function(e,n){return n.isBlock?"\n\n"+e+"\n\n":e}};this.options=extend({},n,e);this.rules=new Rules(this.options)}TurndownService.prototype={
/**
   * The entry point for converting a string or DOM node to Markdown
   * @public
   * @param {String|HTMLElement} input The string or DOM node to convert
   * @returns A Markdown representation of the input
   * @type String
   */
turndown:function(e){if(!canConvert(e))throw new TypeError(e+" is not a string, or an element/document/fragment node.");if(e==="")return"";var n=process.call(this,new RootNode(e,this.options));return postProcess.call(this,n)},
/**
   * Add one or more plugins
   * @public
   * @param {Function|Array} plugin The plugin or array of plugins to add
   * @returns The Turndown instance for chaining
   * @type Object
   */
use:function(e){if(Array.isArray(e))for(var n=0;n<e.length;n++)this.use(e[n]);else{if(typeof e!=="function")throw new TypeError("plugin must be a Function or an Array of Functions");e(this)}return this},
/**
   * Adds a rule
   * @public
   * @param {String} key The unique key of the rule
   * @param {Object} rule The rule
   * @returns The Turndown instance for chaining
   * @type Object
   */
addRule:function(e,n){this.rules.add(e,n);return this},
/**
   * Keep a node (as HTML) that matches the filter
   * @public
   * @param {String|Array|Function} filter The unique key of the rule
   * @returns The Turndown instance for chaining
   * @type Object
   */
keep:function(e){this.rules.keep(e);return this},
/**
   * Remove a node that matches the filter
   * @public
   * @param {String|Array|Function} filter The unique key of the rule
   * @returns The Turndown instance for chaining
   * @type Object
   */
remove:function(e){this.rules.remove(e);return this},
/**
   * Escapes Markdown syntax
   * @public
   * @param {String} string The string to escape
   * @returns A string with Markdown syntax escaped
   * @type String
   */
escape:function(e){return u.reduce((function(e,n){return e.replace(n[0],n[1])}),e)}};
/**
 * Reduces a DOM node down to its Markdown string equivalent
 * @private
 * @param {HTMLElement} parentNode The node to convert
 * @returns A Markdown representation of the node
 * @type String
 */function process(e){var n=this;return l.call(e.childNodes,(function(e,t){t=new Node(t,n.options);var r="";t.nodeType===3?r=t.isCode?t.nodeValue:n.escape(t.nodeValue):t.nodeType===1&&(r=replacementForNode.call(n,t));return join(e,r)}),"")}
/**
 * Appends strings as each rule requires and trims the output
 * @private
 * @param {String} output The conversion output
 * @returns A trimmed version of the ouput
 * @type String
 */function postProcess(e){var n=this;this.rules.forEach((function(t){typeof t.append==="function"&&(e=join(e,t.append(n.options)))}));return e.replace(/^[\t\r\n]+/,"").replace(/[\t\r\n\s]+$/,"")}
/**
 * Converts an element node to its Markdown equivalent
 * @private
 * @param {HTMLElement} node The node to convert
 * @returns A Markdown representation of the node
 * @type String
 */function replacementForNode(e){var n=this.rules.forNode(e);var t=process.call(this,e);var r=e.flankingWhitespace;(r.leading||r.trailing)&&(t=t.trim());return r.leading+n.replacement(t,e,this.options)+r.trailing}
/**
 * Joins replacement to the current output with appropriate number of new lines
 * @private
 * @param {String} output The current conversion output
 * @param {String} replacement The string to append to the output
 * @returns Joined output
 * @type String
 */function join(e,n){var t=trimTrailingNewlines(e);var r=trimLeadingNewlines(n);var i=Math.max(e.length-t.length,n.length-r.length);var a="\n\n".substring(0,i);return t+a+r}
/**
 * Determines whether an input can be converted
 * @private
 * @param {String|HTMLElement} input Describe this parameter
 * @returns Describe what it returns
 * @type String|Object|Array|Boolean|Number
 */function canConvert(e){return e!=null&&(typeof e==="string"||e.nodeType&&(e.nodeType===1||e.nodeType===9||e.nodeType===11))}export{TurndownService as default};

