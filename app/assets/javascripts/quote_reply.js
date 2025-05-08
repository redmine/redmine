function quoteReply(path, selectorForContentElement, textFormatting) {
  const contentElement = $(selectorForContentElement).get(0);
  const selectedRange = QuoteExtractor.extract(contentElement);

  let formatter;

  if (textFormatting === 'common_mark') {
    formatter = new QuoteCommonMarkFormatter();
  } else {
    formatter = new QuoteTextFormatter();
  }

  $.ajax({
    url: path,
    type: 'post',
    data: { quote: formatter.format(selectedRange) }
  });
}

class QuoteExtractor {
  static extract(targetElement) {
    return new QuoteExtractor(targetElement).extract();
  }

  constructor(targetElement) {
    this.targetElement = targetElement;
    this.selection = window.getSelection();
  }

  extract() {
    const range = this.retriveSelectedRange();

    if (!range) {
      return null;
    }

    if (!this.targetElement.contains(range.startContainer)) {
      range.setStartBefore(this.targetElement);
    }
    if (!this.targetElement.contains(range.endContainer)) {
      range.setEndAfter(this.targetElement);
    }

    return range;
  }

  retriveSelectedRange() {
    if (!this.isSelected) {
      return null;
    }

    // Retrive the first range that intersects with the target element.
    // NOTE: Firefox allows to select multiple ranges in the document.
    for (let i = 0; i < this.selection.rangeCount; i++) {
      let range = this.selection.getRangeAt(i);
      if (range.intersectsNode(this.targetElement)) {
        return range;
      }
    }
    return null;
  }

  get isSelected() {
    return this.selection.containsNode(this.targetElement, true);
  }
}

class QuoteTextFormatter {
  format(selectedRange) {
    if (!selectedRange) {
      return null;
    }

    const fragment = document.createElement('div');
    fragment.appendChild(selectedRange.cloneContents());

    // Remove all unnecessary anchor elements
    fragment.querySelectorAll('a.wiki-anchor').forEach(e => e.remove());

    const html = this.adjustLineBreaks(fragment.innerHTML);

    const result = document.createElement('div');
    result.innerHTML = html;

    // Replace continuous line breaks with a single line break and remove tab characters
    return result.textContent
      .trim()
      .replace(/\t/g, '')
      .replace(/\n+/g, "\n");
  }

  adjustLineBreaks(html) {
    return html
      .replace(/<\/(h1|h2|h3|h4|div|p|li|tr)>/g, "\n</$1>")
      .replace(/<br>/g, "\n")
  }
}

class QuoteCommonMarkFormatter {
  format(selectedRange) {
    if (!selectedRange) {
      return null;
    }

    const htmlFragment = this.extractHtmlFragmentFrom(selectedRange);
    const preparedHtml = this.prepareHtml(htmlFragment);

    return this.convertHtmlToCommonMark(preparedHtml);
  }

  extractHtmlFragmentFrom(range) {
    const fragment = document.createElement('div');
    const ancestorNodeName = range.commonAncestorContainer.nodeName;

    if (ancestorNodeName == 'CODE' || ancestorNodeName == '#text') {
      fragment.appendChild(this.wrapPreCode(range));
    } else {
      fragment.appendChild(range.cloneContents());
    }

    return fragment;
  }

  // When only the content within the `<code>` element is selected,
  // the HTML within the selection range does not include the `<pre><code>` element itself.
  // To create a complete code block, wrap the selected content with the `<pre><code>` tags.
  //
  // selected contentes => <pre><code class="ruby">selected contents</code></pre>
  wrapPreCode(range) {
    const rangeAncestor = range.commonAncestorContainer;

    let codeElement = null;

    if (rangeAncestor.nodeName == 'CODE') {
      codeElement = rangeAncestor;
    } else {
      codeElement = rangeAncestor.parentElement.closest('code');
    }

    if (!codeElement) {
      return range.cloneContents();
    }

    const pre = document.createElement('pre');
    const code = codeElement.cloneNode(false);

    code.appendChild(range.cloneContents());
    pre.appendChild(code);

    return pre;
  }

  convertHtmlToCommonMark(html) {
    const turndownService = new TurndownService({
      codeBlockStyle: 'fenced',
      headingStyle: 'atx'
    });

    turndownService.addRule('del', {
      filter: ['del'],
      replacement: content => `~~${content}~~`
    });

    turndownService.addRule('checkList', {
      filter: node => {
        return node.type === 'checkbox' && node.parentNode.nodeName === 'LI';
      },
      replacement: (content, node) => {
        return node.checked ? '[x]' : '[ ]';
      }
    });

    // Table does not maintain its original format,
    // and the text within the table is displayed as it is
    //
    // | A | B | C |
    // |---|---|---|
    // | 1 | 2 | 3 |
    // =>
    // A B C
    // 1 2 3
    turndownService.addRule('table', {
      filter: ['td', 'th'],
      replacement: (content, node) => {
        const separator = node.parentElement.lastElementChild === node ? '' : ' ';
        return content + separator;
      }
    });
    turndownService.addRule('tableHeading', {
      filter: ['thead', 'tbody', 'tfoot', 'tr'],
      replacement: (content, _node) => content
    });
    turndownService.addRule('tableRow', {
      filter: ['tr'],
      replacement: (content, _node) => {
        return content + '\n'
      }
    });

    return turndownService.turndown(html);
  }

  prepareHtml(htmlFragment) {
    // Remove all anchor elements.
    // <h1>Title1<a href="#Title" class="wiki-anchor">¶</a></h1> => <h1>Title1</h1>
    htmlFragment.querySelectorAll('a.wiki-anchor').forEach(e => e.remove());

    // Convert code highlight blocks to CommonMark format code blocks.
    // <code class="ruby" data-language="ruby"> => <code class="language-ruby" data-language="ruby">
    htmlFragment.querySelectorAll('code[data-language]').forEach(e => {
      e.classList.replace(e.dataset['language'], 'language-' + e.dataset['language'])
    });

    return htmlFragment.innerHTML;
  }
}
