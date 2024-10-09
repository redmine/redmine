/**
 * This file is part of DotClear.
 * Copyright (c) 2005 Nicolas Martin & Olivier Meunier and contributors. All rights reserved.
 * This code is released under the GNU General Public License.
 *
 * Modified by JP LANG for common_mark formatting
 */

// strong
jsToolBar.prototype.elements.strong = {
  type: 'button',
  title: 'Strong',
  shortcut: 'b',
  fn: {
    wiki: function() { this.singleTag('**') }
  }
}

// em
jsToolBar.prototype.elements.em = {
  type: 'button',
  title: 'Italic',
  shortcut: 'i',
  fn: {
    wiki: function() { this.singleTag("*") }
  }
}

// u
jsToolBar.prototype.elements.ins = {
  type: 'button',
  title: 'Underline',
  shortcut: 'u',
  fn: {
    wiki: function() { this.singleTag('<u>', '</u>') }
  }
}

// del
jsToolBar.prototype.elements.del = {
  type: 'button',
  title: 'Deleted',
  fn: {
    wiki: function() { this.singleTag('~~') }
  }
}

// code
jsToolBar.prototype.elements.code = {
  type: 'button',
  title: 'Code',
  fn: {
    wiki: function() { this.singleTag('`') }
  }
}

// spacer
jsToolBar.prototype.elements.space1 = {type: 'space'}

// headings
jsToolBar.prototype.elements.h1 = {
  type: 'button',
  title: 'Heading 1',
  fn: {
    wiki: function() {
      this.encloseLineSelection('# ', '',function(str) {
        str = str.replace(/^#+\s+/, '')
        return str;
      });
    }
  }
}
jsToolBar.prototype.elements.h2 = {
  type: 'button',
  title: 'Heading 2',
  fn: {
    wiki: function() {
      this.encloseLineSelection('## ', '',function(str) {
        str = str.replace(/^#+\s+/, '')
        return str;
      });
    }
  }
}
jsToolBar.prototype.elements.h3 = {
  type: 'button',
  title: 'Heading 3',
  fn: {
    wiki: function() {
      this.encloseLineSelection('### ', '',function(str) {
        str = str.replace(/^#+\s+/, '')
        return str;
      });
    }
  }
}

// spacer
jsToolBar.prototype.elements.space2 = {type: 'space'}

// ul
jsToolBar.prototype.elements.ul = {
  type: 'button',
  title: 'Unordered list',
  fn: {
    wiki: function() {
      this.encloseLineSelection('','',function(str) {
        str = str.replace(/\r/g,'');
        return str.replace(/(\n|^)[#-]?\s*/g,"$1* ");
      });
    }
  }
}

// ol
jsToolBar.prototype.elements.ol = {
  type: 'button',
  title: 'Ordered list',
  fn: {
    wiki: function() {
      this.encloseLineSelection('','',function(str) {
        str = str.replace(/\r/g,'');
        return str.replace(/(\n|^)[*-]?\s*/g,"$11. ");
      });
    }
  }
}

// tl
jsToolBar.prototype.elements.tl = {
  type: 'button',
  title: 'Task list',
  fn: {
    wiki: function() {
      this.encloseLineSelection('','',function(str) {
        str = str.replace(/\r/g,'');
        return str.replace(/(\n|^)[*-]?\s*/g,"$1* [ ] ");
      });
    }
  }
}

// spacer
jsToolBar.prototype.elements.space3 = {type: 'space'}

// bq
jsToolBar.prototype.elements.bq = {
  type: 'button',
  title: 'Quote',
  fn: {
    wiki: function() {
      this.encloseLineSelection('','',function(str) {
        str = str.replace(/\r/g,'');
        return str.replace(/(\n|^)( *)([^\n]*)/g,"$1> $2$3");
      });
    }
  }
}

// unbq
jsToolBar.prototype.elements.unbq = {
  type: 'button',
  title: 'Unquote',
  fn: {
    wiki: function() {
      this.encloseLineSelection('','',function(str) {
        str = str.replace(/\r/g,'');
        return str.replace(/(\n|^) *(> ?)?( *)([^\n]*)/g,"$1$3$4");
      });
    }
  }
}

// table
jsToolBar.prototype.elements.table = {
  type: 'button',
  title: 'Table',
  fn: {
    wiki: function() {
      var This = this;
      this.tableMenu(function(cols, rowCount){
        This.encloseLineSelection(
          '|'+cols.join(' |')+' |\n' +                                   // header
          Array(cols.length+1).join('|--')+'|\n' +                       // second line
          Array(rowCount+1).join(Array(cols.length+1).join('|  ')+'|\n') // cells
        );
      });
    }
  }
}

// pre
jsToolBar.prototype.elements.pre = {
  type: 'button',
  title: 'Preformatted text',
  fn: {
    wiki: function() { this.encloseLineSelection('```\n', '\n```') }
  }
}

// Code highlighting
jsToolBar.prototype.elements.precode = {
  type: 'button',
  title: 'Highlighted code',
  fn: {
    wiki: function() {
      var This = this;
      this.precodeMenu(function(lang){
        This.encloseLineSelection('``` ' + lang + '\n', '\n```\n');
      });
    }
  }
}

// spacer
jsToolBar.prototype.elements.space4 = {type: 'space'}

// wiki page
jsToolBar.prototype.elements.link = {
  type: 'button',
  title: 'Wiki link',
  fn: {
    wiki: function() { this.encloseSelection("[[", "]]") }
  }
}
// image
jsToolBar.prototype.elements.img = {
  type: 'button',
  title: 'Image',
  fn: {
    wiki: function() { this.encloseSelection("![](", ")") }
  }
}

// spacer
jsToolBar.prototype.elements.space5 = {type: 'space'}
// help
jsToolBar.prototype.elements.help = {
  type: 'button',
  title: 'Help',
  fn: {
    wiki: function() { window.open(this.help_link, '', 'resizable=yes, location=no, width=300, height=640, menubar=no, status=no, scrollbars=yes') }
  }
}
