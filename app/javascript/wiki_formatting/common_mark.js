/**
 * Redmine - project management software
 * Copyright (C) 2006-  Jean-Philippe Lang
 * This code is released under the GNU General Public License.
 */

// CommonMark markup inserted by the wiki toolbar buttons.
// Each function receives the editor (the wiki-toolbar controller).

const heading = (level) => (editor) =>
  editor.wrapLines(`${'#'.repeat(level)} `, '', (text) => text.replace(/^#+\s+/, ''))

export default {
  strong: (editor) => editor.wrap('**'),
  em: (editor) => editor.wrap('*'),
  ins: (editor) => editor.wrap('<u>', '</u>'),
  del: (editor) => editor.wrap('~~'),
  code: (editor) => editor.wrap('`'),

  h1: heading(1),
  h2: heading(2),
  h3: heading(3),

  ul: (editor) => editor.replaceLines(/(\n|^)[#-]?\s*/g, '$1* '),
  ol: (editor) => editor.replaceLines(/(\n|^)[*-]?\s*/g, '$11. '),
  tl: (editor) => editor.replaceLines(/(\n|^)[*-]?\s*/g, '$1* [ ] '),

  bq: (editor) => editor.replaceLines(/(\n|^)( *)([^\n]*)/g, '$1> $2$3'),
  unbq: (editor) => editor.replaceLines(/(\n|^) *(> ?)?( *)([^\n]*)/g, '$1$3$4'),
  pre: (editor) => editor.wrapLines('```\n', '\n```'),
  precode: (editor, lang) => editor.wrapLines(`\`\`\` ${lang}\n`, '\n```\n'),
  table: (editor, cols, rows) => {
    const header = editor.columnNames(cols).map((name) => `${name} `)
    editor.wrapLines(`|${header.join('|')}|\n` + `|${'--|'.repeat(cols)}\n` + `|${'  |'.repeat(cols)}\n`.repeat(rows))
  },

  link: (editor) => editor.wrap('[[', ']]'),
  img: (editor) => editor.wrap('![](', ')')
}
