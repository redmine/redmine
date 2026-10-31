/**
 * Redmine - project management software
 * Copyright (C) 2006-  Jean-Philippe Lang
 * This code is released under the GNU General Public License.
 */

// Textile markup inserted by the wiki toolbar buttons.
// Each function receives the editor (the wiki-toolbar controller).

const heading = (level) => (editor) =>
  editor.wrapLines(`h${level}. `, '', (text) => text.replace(/^h\d+\.\s+/, ''))

export default {
  strong: (editor) => editor.wrap('*'),
  em: (editor) => editor.wrap('_'),
  ins: (editor) => editor.wrap('+'),
  del: (editor) => editor.wrap('-'),
  code: (editor) => editor.wrap('@'),

  h1: heading(1),
  h2: heading(2),
  h3: heading(3),

  ul: (editor) => editor.replaceLines(/(\n|^)[#-]?\s*/g, '$1* '),
  ol: (editor) => editor.replaceLines(/(\n|^)[*-]?\s*/g, '$1# '),

  bq: (editor) => editor.replaceLines(/(\n|^)( *)([^\n]*)/g, '$1> $2$3'),
  unbq: (editor) => editor.replaceLines(/(\n|^) *(> ?)?( *)([^\n]*)/g, '$1$3$4'),
  pre: (editor) => editor.wrapLines('<pre>\n', '\n</pre>'),
  precode: (editor, lang) => editor.wrapLines(`<pre><code class="${lang}">\n`, '\n</code></pre>\n'),
  table: (editor, cols, rows) => {
    const header = editor.columnNames(cols).map((name) => `_.${name}`)
    editor.wrapLines(`|${header.join('|')}|\n` + `|${'  |'.repeat(cols)}\n`.repeat(rows))
  },

  link: (editor) => editor.wrap('[[', ']]'),
  img: (editor) => editor.wrap('!', '!')
}
