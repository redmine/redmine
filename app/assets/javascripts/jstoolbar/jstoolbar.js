/**
 * This file is part of DotClear.
 * Copyright (c) 2005 Nicolas Martin & Olivier Meunier and contributors. All rights reserved.
 * This code is released under the GNU General Public License.
 *
 * Modified by JP LANG for multiple text formatting
 */

let lastJstPreviewed = null;
const isMac = Boolean(navigator.platform.toLowerCase().match(/mac/));

function jsToolBar(textarea) {
  if (!document.createElement) { return; }

  if (!textarea) { return; }

  if ((typeof(document["selection"]) == "undefined")
  && (typeof(textarea["setSelectionRange"]) == "undefined")) {
    return;
    }

  this.textarea = textarea;

  this.toolbarBlock = document.createElement('div');
  this.toolbarBlock.className = 'jstBlock';
  this.textarea.parentNode.insertBefore(this.toolbarBlock, this.textarea);

  this.editor = document.createElement('div');
  this.editor.className = 'jstEditor';

  this.preview = document.createElement('div');
  this.preview.className = 'wiki wiki-preview hidden';
  this.preview.setAttribute('id', 'preview_' + textarea.getAttribute('id'));

  this.editor.appendChild(this.textarea);
  this.editor.appendChild(this.preview);

  this.tabsBlock = document.createElement('div');
  this.tabsBlock.className = 'jstTabs tabs';

  var This = this;

  this.textarea.onkeydown = function(event) { This.keyboardShortcuts.call(This, event); };

  this.editTab = new jsTab('Edit', true);
  this.editTab.onclick = function(event) { This.hidePreview.call(This, event); return false; };

  this.previewTab = new jsTab('Preview');
  this.previewTab.onclick = function(event) { This.showPreview.call(This, event); return false; };

  var elementsTab = document.createElement('li');
  elementsTab.classList = 'tab-elements';

  var tabs = document.createElement('ul');
  tabs.appendChild(this.editTab);
  tabs.appendChild(this.previewTab);
  tabs.appendChild(elementsTab);
  this.tabsBlock.appendChild(tabs);

  this.toolbar = document.createElement("div");
  this.toolbar.className = 'jstElements';
  elementsTab.appendChild(this.toolbar);

  this.toolbarBlock.appendChild(this.tabsBlock);
  this.toolbarBlock.appendChild(this.editor);

  // Dragable resizing
  if (this.editor.addEventListener && navigator.appVersion.match(/\bMSIE\b/))
  {
    this.handle = document.createElement('div');
    this.handle.className = 'jstHandle';
    var dragStart = this.resizeDragStart;
    var This = this;
    this.handle.addEventListener('mousedown',function(event) { dragStart.call(This,event); },false);
    // fix memory leak in Firefox (bug #241518)
    window.addEventListener('unload',function() {
      var del = This.handle.parentNode.removeChild(This.handle);
      delete(This.handle);
    },false);

    this.editor.parentNode.insertBefore(this.handle,this.editor.nextSibling);
  }

  this.context = null;
  this.toolNodes = {}; // lorsque la toolbar est dessinée , cet objet est garni
                       // de raccourcis vers les éléments DOM correspondants aux outils.
}

function jsTab(name, selected) {
  selected = selected || false;
  if(typeof jsToolBar.strings == 'undefined') {
    var tabName = name || null;
  } else {
    var tabName = jsToolBar.strings[name] || name || null;
  }

  var tab = document.createElement('li');
  var link = document.createElement('a');
  link.setAttribute('href', '#');
  link.innerText = tabName;
  link.className = 'tab-' + name.toLowerCase();

  if (selected == true) {
    link.classList.add('selected');
  }
  tab.appendChild(link)

  return tab;
}
function jsButton(title, fn, scope, className) {
  if(typeof jsToolBar.strings == 'undefined') {
    this.title = title || null;
  } else {
      this.title = jsToolBar.strings[title] || title || null;
  }
  this.fn = fn || function(){};
  this.scope = scope || null;
  this.className = className || null;
}
jsButton.prototype.draw = function() {
  if (!this.scope) return null;

  var button = document.createElement('button');
  button.setAttribute('type','button');
  button.tabIndex = 200;
  if (this.className) button.className = this.className;
  button.title = this.title;
  var span = document.createElement('span');
  span.appendChild(document.createTextNode(this.title));
  button.appendChild(span);

  if (this.icon != undefined) {
    button.style.backgroundImage = 'url('+this.icon+')';
  }

  if (typeof(this.fn) == 'function') {
    var This = this;
    button.onclick = function() { try { This.fn.apply(This.scope, arguments) } catch (e) {} return false; };
  }
  return button;
}

function jsSpace(className) {
  this.className = className || null;
  this.width = null;
}
jsSpace.prototype.draw = function() {
  var span = document.createElement('span');
  span.appendChild(document.createTextNode(String.fromCharCode(160)));
  span.className = 'jstSpacer' + (this.className ? ' ' + this.className : '');
  if (this.width) span.style.marginRight = this.width+'px';

  return span;
}

function jsCombo(title, options, scope, fn, className) {
  this.title = title || null;
  this.options = options || null;
  this.scope = scope || null;
  this.fn = fn || function(){};
  this.className = className || null;
}
jsCombo.prototype.draw = function() {
  if (!this.scope || !this.options) return null;

  var select = document.createElement('select');
  if (this.className) select.className = className;
  select.title = this.title;

  for (var o in this.options) {
    //var opt = this.options[o];
    var option = document.createElement('option');
    option.value = o;
    option.appendChild(document.createTextNode(this.options[o]));
    select.appendChild(option);
  }

  var This = this;
  select.onchange = function() {
    try {
      This.fn.call(This.scope, this.value);
    } catch (e) { alert(e); }

    return false;
  }

  return select;
}


jsToolBar.prototype = {
  base_url: '',
  mode: 'wiki',
  elements: {},
  help_link: '',
  shortcuts: {},

  getMode: function() {
    return this.mode;
  },

  setMode: function(mode) {
    this.mode = mode || 'wiki';
  },

  switchMode: function(mode) {
    mode = mode || 'wiki';
    this.draw(mode);
  },

  setHelpLink: function(link) {
    this.help_link = link;
  },

  setPreviewUrl: function(url) {
    this.previewTab.firstChild.setAttribute('data-url', url);
  },

  button: function(toolName) {
    var tool = this.elements[toolName];
    if (typeof tool.fn[this.mode] != 'function') return null;

    const className = 'jstb_' + toolName;
    let title = tool.title

    if (tool.hasOwnProperty('shortcut')) {
      this.shortcuts[tool.shortcut] = className;
      title = this.buttonTitleWithShortcut(tool.title, tool.shortcut)
    }

    var b = new jsButton(title, tool.fn[this.mode], this, className);
    if (tool.icon != undefined) b.icon = tool.icon;

    return b;
  },
  buttonTitleWithShortcut: function(title, shortcutKey) {
    if(typeof jsToolBar.strings == 'undefined') {
      var i18nTitle = title || null;
    } else {
      var i18nTitle = jsToolBar.strings[title] || title || null;
    }

    if (isMac) {
      return i18nTitle + " (⌘" + shortcutKey.toUpperCase() + ")";
    } else {
      return i18nTitle + " (Ctrl+" + shortcutKey.toUpperCase() + ")";
    }
  },
  space: function(toolName) {
    var tool = new jsSpace(toolName)
    if (this.elements[toolName].width !== undefined)
      tool.width = this.elements[toolName].width;
    return tool;
  },
  combo: function(toolName) {
    var tool = this.elements[toolName];
    var length = tool[this.mode].list.length;

    if (typeof tool[this.mode].fn != 'function' || length == 0) {
      return null;
    } else {
      var options = {};
      for (var i=0; i < length; i++) {
        var opt = tool[this.mode].list[i];
        options[opt] = tool.options[opt];
      }
      return new jsCombo(tool.title, options, this, tool[this.mode].fn);
    }
  },
  draw: function(mode) {
    this.setMode(mode);

    // Empty toolbar
    while (this.toolbar.hasChildNodes()) {
      this.toolbar.removeChild(this.toolbar.firstChild)
    }
    this.toolNodes = {}; // vide les raccourcis DOM/**/

    // Draw toolbar elements
    var b, tool, newTool;

    for (var i in this.elements) {
      b = this.elements[i];

      var disabled =
      b.type == undefined || b.type == ''
      || (b.disabled != undefined && b.disabled)
      || (b.context != undefined && b.context != null && b.context != this.context);

      if (!disabled && typeof this[b.type] == 'function') {
        tool = this[b.type](i);
        if (tool) newTool = tool.draw();
        if (newTool) {
          this.toolNodes[i] = newTool; //mémorise l'accès DOM pour usage éventuel ultérieur
          this.toolbar.appendChild(newTool);
        }
      }
    }
  },

  singleTag: function(stag,etag) {
    stag = stag || null;
    etag = etag || stag;

    if (!stag || !etag) { return; }

    this.encloseSelection(stag,etag);
  },

  encloseLineSelection: function(prefix, suffix, fn) {
    this.textarea.focus();

    prefix = prefix || '';
    suffix = suffix || '';

    var start, end, sel, scrollPos, subst, res;

    if (typeof(document["selection"]) != "undefined") {
      sel = document.selection.createRange().text;
    } else if (typeof(this.textarea["setSelectionRange"]) != "undefined") {
      start = this.textarea.selectionStart;
      end = this.textarea.selectionEnd;
      scrollPos = this.textarea.scrollTop;
      // go to the start of the line
      start = this.textarea.value.substring(0, start).replace(/[^\r\n]*$/g,'').length;
      // go to the end of the line
      end = this.textarea.value.length - this.textarea.value.substring(end, this.textarea.value.length).replace(/^[^\r\n]*/, '').length;
      sel = this.textarea.value.substring(start, end);
    }

    if (sel.match(/ $/)) { // exclude ending space char, if any
      sel = sel.substring(0, sel.length - 1);
      suffix = suffix + " ";
    }

    if (typeof(fn) == 'function') {
      res = (sel) ? fn.call(this,sel) : fn('');
    } else {
      res = (sel) ? sel : '';
    }

    subst = prefix + res + suffix;

    if (typeof(document["selection"]) != "undefined") {
      document.selection.createRange().text = subst;
      var range = this.textarea.createTextRange();
      range.collapse(false);
      range.move('character', -suffix.length);
      range.select();
    } else if (typeof(this.textarea["setSelectionRange"]) != "undefined") {
      this.textarea.value = this.textarea.value.substring(0, start) + subst +
      this.textarea.value.substring(end);
      if (sel || (!prefix && start === end)) {
        this.textarea.setSelectionRange(start + subst.length, start + subst.length);
      } else {
        this.textarea.setSelectionRange(start + prefix.length, start + prefix.length);
      }
      this.textarea.scrollTop = scrollPos;
    }
  },

  encloseSelection: function(prefix, suffix, fn) {
    this.textarea.focus();
    prefix = prefix || '';
    suffix = suffix || '';

    var start, end, sel, scrollPos, subst, res;

    if (typeof(document["selection"]) != "undefined") {
      sel = document.selection.createRange().text;
    } else if (typeof(this.textarea["setSelectionRange"]) != "undefined") {
      start = this.textarea.selectionStart;
      end = this.textarea.selectionEnd;
      scrollPos = this.textarea.scrollTop;
      sel = this.textarea.value.substring(start, end);
      if (start > 0 && this.textarea.value.substr(start-1, 1).match(/\S/)) {
        prefix = ' ' + prefix;
      }
      if (this.textarea.value.substr(end, 1).match(/\S/)) {
        suffix = suffix + ' ';
      }
    }
    if (sel.match(/ $/)) { // exclude ending space char, if any
      sel = sel.substring(0, sel.length - 1);
      suffix = suffix + " ";
    }

    if (typeof(fn) == 'function') {
      res = (sel) ? fn.call(this,sel) : fn('');
    } else {
      res = (sel) ? sel : '';
    }

    subst = prefix + res + suffix;

    if (typeof(document["selection"]) != "undefined") {
      document.selection.createRange().text = subst;
      var range = this.textarea.createTextRange();
      range.collapse(false);
      range.move('character', -suffix.length);
      range.select();
//      this.textarea.caretPos -= suffix.length;
    } else if (typeof(this.textarea["setSelectionRange"]) != "undefined") {
      this.textarea.value = this.textarea.value.substring(0, start) + subst +
      this.textarea.value.substring(end);
      if (sel) {
        this.textarea.setSelectionRange(start + subst.length, start + subst.length);
      } else {
        this.textarea.setSelectionRange(start + prefix.length, start + prefix.length);
      }
      this.textarea.scrollTop = scrollPos;
    }
  },
  showPreview: function(event) {
    if (event.target.classList.contains('selected')) { return; }
    lastJstPreviewed = this.toolbarBlock;
    this.preview.setAttribute('style', 'min-height: ' + this.textarea.clientHeight + 'px;')
    this.toolbar.classList.add('hidden');
    this.textarea.classList.add('hidden');
    this.preview.classList.remove('hidden');
    this.tabsBlock.querySelector('.tab-edit').classList.remove('selected');
    event.target.classList.add('selected');
  },
  hidePreview: function(event) {
    if (event.target.classList.contains('selected')) { return; }
    this.toolbar.classList.remove('hidden');
    this.textarea.classList.remove('hidden');
    this.textarea.focus();
    this.preview.classList.add('hidden');
    this.tabsBlock.querySelector('.tab-preview').classList.remove('selected');
    event.target.classList.add('selected');
  },
  keyboardShortcuts: function(e) {
    let stop = false;
    if (isToogleEditPreviewShortcut(e)) {
      // Switch to preview only if Edit tab is selected when the event triggers.
      if (this.tabsBlock.querySelector('.tab-edit.selected')) {
        stop = true
        this.tabsBlock.querySelector('.tab-preview').click();
      }
    }
    if (isModifierKey(e) && this.shortcuts.hasOwnProperty(e.key.toLowerCase())) {
      stop = true
      this.toolbar.querySelector("." + this.shortcuts[e.key.toLowerCase()]).click();
    }
    if (stop) {
      e.stopPropagation();
      e.preventDefault();
    }
  },
  stripBaseURL: function(url) {
    if (this.base_url != '') {
      var pos = url.indexOf(this.base_url);
      if (pos == 0) {
        url = url.substr(this.base_url.length);
      }
    }

    return url;
  }
};

/** Resizer
-------------------------------------------------------- */
jsToolBar.prototype.resizeSetStartH = function() {
  this.dragStartH = this.textarea.offsetHeight + 0;
};
jsToolBar.prototype.resizeDragStart = function(event) {
  var This = this;
  this.dragStartY = event.clientY;
  this.resizeSetStartH();
  document.addEventListener('mousemove', this.dragMoveHdlr=function(event){This.resizeDragMove(event);}, false);
  document.addEventListener('mouseup', this.dragStopHdlr=function(event){This.resizeDragStop(event);}, false);
};

jsToolBar.prototype.resizeDragMove = function(event) {
  this.textarea.style.height = (this.dragStartH+event.clientY-this.dragStartY)+'px';
};

jsToolBar.prototype.resizeDragStop = function(event) {
  document.removeEventListener('mousemove', this.dragMoveHdlr, false);
  document.removeEventListener('mouseup', this.dragStopHdlr, false);
};

/* Code highlighting menu */
jsToolBar.prototype.precodeMenu = function(fn){
  var hlLanguages = window.userHlLanguages;
  var menu = $("<ul style='position:absolute;'></ul>");
  for (var i = 0; i < hlLanguages.length; i++) {
    var langItem = $('<div></div>').text(hlLanguages[i]);
    $("<li></li>").html(langItem).appendTo(menu).mousedown(function(){
      fn($(this).text());
    });
  }
  $("body").append(menu);
  menu.menu().width(150).position({
    my: "left top",
    at: "left bottom",
    of: this.toolNodes['precode']
  });
  $(document).on("mousedown", function() {
    menu.remove();
  });
  return false;
};

/* Table generator */
jsToolBar.prototype.tableMenu = function(fn){
  var alphabets = "ABCDEFGHIJ".split('');
  var menu = $("<table class='table-generator'></table>");

  for (var r = 1;  r <= 5;  r++) {
    var row = $("<tr></tr>").appendTo(menu);
    for (var c = 1;  c <= 10;  c++) {
      $("<td data-row="+r+" data-col="+c+" title="+(c)+'&times;'+(r)+"></td>").mousedown(function(){
        fn(alphabets.slice(0, $(this).data('col')), $(this).data('row'));
      }).hover(function(){
        var hoverRow = $(this).data('row');
        var hoverCol = $(this).data('col');
        $(this).closest('table').find('td').each(function(_index, element){
          if ($(element).data('row') <= hoverRow && $(element).data('col') <= hoverCol){
            $(element).addClass('selected-cell');
          } else {
            $(element).removeClass('selected-cell');
          }
        });
      }).appendTo(row);
    }
  }
  $("body").append(menu);
  menu.position({
    my: "left top",
    at: "left bottom",
    of: this.toolNodes['table']
  });
  $(document).on("mousedown", function() {
    menu.remove();
  });
  return false;
};

$(document).keydown(function(e) {
  if (isToogleEditPreviewShortcut(e)) {
    if (lastJstPreviewed !== null) {
      e.preventDefault();
      e.stopPropagation();
      lastJstPreviewed.querySelector('.tab-edit').click();
      lastJstPreviewed = null;
    }
  }
});

function isToogleEditPreviewShortcut(e) {
  if ((e.metaKey || e.ctrlKey) && e.shiftKey && e.key.toLowerCase() === 'p') {
    return true;
  } else {
    return false;
  }
}
function isModifierKey(e) {
  if (isMac && e.metaKey) {
    return true;
  } else if (!isMac && e.ctrlKey) {
    return true;
  } else {
    return false;
  }
}
