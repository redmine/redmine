# redminehelper: Redmine helper extension for Mercurial
#
# Copyright 2010 Alessio Franceschelli (alefranz.net)
# Copyright 2010-2011 Yuya Nishihara <yuya@tcha.org>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

# [Nomadia-changes] Patch from Redmine.org #33784 : adapt to Python 3.0

"""helper commands for Redmine to reduce the number of hg calls

To test this extension, please try::

    $ hg --config extensions.redminehelper=redminehelper.py rhsummary

I/O encoding:

:file path: urlencoded, raw string
:tag name: utf-8
:branch name: utf-8
:node: hex string

Output example of rhsummary::

    <?xml version="1.0"?>
    <rhsummary>
      <repository root="/foo/bar">
        <tip revision="1234" node="abcdef0123..."/>
        <tag revision="123" node="34567abc..." name="1.1.1"/>
        <branch .../>
        ...
      </repository>
    </rhsummary>

Output example of rhmanifest::

    <?xml version="1.0"?>
    <rhmanifest>
      <repository root="/foo/bar">
        <manifest revision="1234" path="lib">
          <file name="diff.rb" revision="123" node="34567abc..." time="12345"
                 size="100"/>
          ...
          <dir name="redmine"/>
          ...
        </manifest>
      </repository>
    </rhmanifest>
"""
import re, time, html, urllib
from mercurial import cmdutil, commands, node, error, hg, registrar

cmdtable = {}
command = registrar.command(cmdtable) if hasattr(registrar, 'command') else cmdutil.command(cmdtable)

_x = lambda s: html.escape(s.decode('utf-8')).encode('utf-8')
_u = lambda s: html.escape(urllib.parse.quote(s)).encode('utf-8')

def unquoteplus(*args, **kwargs):
    return urllib.parse.unquote_to_bytes(*args, **kwargs).replace(b'+', b' ')

def _changectx(repo, rev):
    if isinstance(rev, bytes):
       rev = repo.lookup(rev)
    if hasattr(repo, 'changectx'):
        return repo.changectx(rev)
    else:
        return repo[rev]

def _tip(ui, repo):
    # see mercurial/commands.py:tip
    def tiprev():
        try:
            return len(repo) - 1
        except TypeError:  # Mercurial < 1.1
            return repo.changelog.count() - 1
    tipctx = _changectx(repo, tiprev())
    ui.write(b'<tip revision="%d" node="%s"/>\n'
             % (tipctx.rev(), _x(node.hex(tipctx.node()))))

_SPECIAL_TAGS = (b'tip',)

def _tags(ui, repo):
    # see mercurial/commands.py:tags
    for t, n in reversed(repo.tagslist()):
        if t in _SPECIAL_TAGS:
            continue
        try:
            r = repo.changelog.rev(n)
        except error.LookupError:
            continue
        ui.write(b'<tag revision="%d" node="%s" name="%s"/>\n'
                 % (r, _x(node.hex(n)), _u(t)))

def _branches(ui, repo):
    # see mercurial/commands.py:branches
    def iterbranches():
        if getattr(repo, 'branchtags', None) is not None:
            # Mercurial < 2.9
            for t, n in repo.branchtags().iteritems():
                yield t, n, repo.changelog.rev(n)
        else:
            for tag, heads, tip, isclosed in repo.branchmap().iterbranches():
                yield tag, tip, repo.changelog.rev(tip)
    def branchheads(branch):
        try:
            return repo.branchheads(branch, closed=False)
        except TypeError:  # Mercurial < 1.2
            return repo.branchheads(branch)
    def lookup(rev, n):
        try:
            return repo.lookup(str(rev).encode('utf-8'))
        except RuntimeError:
            return n
    for t, n, r in sorted(iterbranches(), key=lambda e: e[2], reverse=True):
        if lookup(r, n) in branchheads(t):
            ui.write(b'<branch revision="%d" node="%s" name="%s"/>\n'
                     % (r, _x(node.hex(n)), _u(t)))

def _manifest(ui, repo, path, rev, path_encoding):
    ctx = _changectx(repo, rev)
    ui.write(b'<manifest revision="%d" path="%s">\n'
             % (ctx.rev(), _u(path.decode(path_encoding))))

    known = set()
    pathprefix = (path.decode(path_encoding).rstrip('/') + '/').lstrip('/')
    for f, n in sorted(ctx.manifest().iteritems(), key=lambda e: e[0]):
        fstr = f.decode(path_encoding)
        if not fstr.startswith(pathprefix):
             continue
        name = re.sub(r'/.*', '/', fstr[len(pathprefix):])
        if name in known:
            continue
        known.add(name)

        if name.endswith('/'):
            ui.write(b'<dir name="%s"/>\n'
                     % _x(urllib.parse.quote(name[:-1]).encode('utf-8')))
        else:
            fctx = repo.filectx(f, fileid=n)
            tm, tzoffset = fctx.date()
            ui.write(b'<file name="%s" revision="%d" node="%s" '
                     b'time="%d" size="%d"/>\n'
                     % (_u(name), fctx.rev(), _x(node.hex(fctx.node())),
                        tm, fctx.size(), ))

    ui.write(b'</manifest>\n')

@command(b'rhannotate',
         [(b'r', b'rev', b'', b'revision'),
          (b'u', b'user', None, b'list the author (long with -v)'),
          (b'n', b'number', None, b'list the revision number (default)'),
          (b'c', b'changeset', None, b'list the changeset'),
         ],
         b'hg rhannotate [-r REV] [-u] [-n] [-c] FILE...')
def rhannotate(ui, repo, *pats, **opts):
    rev = unquoteplus(opts.pop('rev', b''))
    opts['rev'] = rev
    return commands.annotate(ui, repo, *map(unquoteplus, pats), **opts)

@command(b'rhcat',
               [(b'r', b'rev', b'', b'revision')],
               b'hg rhcat ([-r REV] ...) FILE...')
def rhcat(ui, repo, file1, *pats, **opts):
    rev = unquoteplus(opts.pop('rev', b''))
    opts['rev'] = rev
    return commands.cat(ui, repo, unquoteplus(file1), *map(unquoteplus, pats), **opts)

@command(b'rhdiff',
               [(b'r', b'rev', [], b'revision'),
                (b'c', b'change', b'', b'change made by revision')],
               b'hg rhdiff ([-c REV] | [-r REV] ...) [FILE]...')
def rhdiff(ui, repo, *pats, **opts):
    """diff repository (or selected files)"""
    change = opts.pop('change', None)
    if change:  # add -c option for Mercurial<1.1
        base = _changectx(repo, change).parents()[0].rev()
        opts['rev'] = [base, change]
    opts['nodates'] = True
    return commands.diff(ui, repo, *map(unquoteplus, pats), **opts)

@command(b'rhlog',
                   [
                    (b'r', b'rev', [], b'show the specified revision'),
                    (b'b', b'branch', [],
                       b'show changesets within the given named branch'),
                    (b'l', b'limit', b'',
                         b'limit number of changes displayed'),
                    (b'd', b'date', b'',
                         b'show revisions matching date spec'),
                    (b'u', b'user', [],
                      b'revisions committed by user'),
                    (b'', b'from', b'',
                      b''),
                    (b'', b'to', b'',
                      b''),
                    (b'', b'rhbranch', b'',
                      b''),
                    (b'', b'template', b'',
                       b'display with template')],
                   b'hg rhlog [OPTION]... [FILE]')
def rhlog(ui, repo, *pats, **opts):
    rev      = opts.pop('rev')
    bra0     = opts.pop('branch')
    from_rev = unquoteplus(opts.pop('from', b''))
    to_rev   = unquoteplus(opts.pop('to'  , b''))
    bra      = unquoteplus(opts.pop('rhbranch', b''))
    from_rev = from_rev.replace(b'"', b'\\"')
    to_rev   = to_rev.replace(b'"', b'\\"')
    if (from_rev != b'') or (to_rev != b''):
        if from_rev != b'':
            quotefrom = b'"%s"' % (from_rev)
        else:
            quotefrom = from_rev
        if to_rev != b'':
            quoteto = b'"%s"' % (to_rev)
        else:
            quoteto = to_rev
        opts['rev'] = [b'%s:%s' % (quotefrom, quoteto)]
        opts['rev'] = rev
    if (bra != b''):
        opts['branch'] = [bra]
    return commands.log(ui, repo, *map(unquoteplus, pats), **opts)

@command(b'rhmanifest',
                   [(b'r', b'rev', b'', b'show the specified revision')],
                   b'hg rhmanifest -r REV [PATH]')
def rhmanifest(ui, repo, path=b'', **opts):
    """output the sub-manifest of the specified directory"""
    ui.write(b'<?xml version="1.0"?>\n')
    ui.write(b'<rhmanifest>\n')
    ui.write(b'<repository root="%s">\n' % _u(repo.root))
    try:
        path_encoding=ui.config(b'redminehelper',b'path_encoding',b'utf-8')
        path_encoding=bytearray(path_encoding).decode('ascii')
        _manifest(ui, repo, unquoteplus(path), unquoteplus(opts.get('rev')), path_encoding)
    finally:
        ui.write(b'</repository>\n')
        ui.write(b'</rhmanifest>\n')

@command(b'rhsummary', [], b'hg rhsummary')
def rhsummary(ui, repo, **opts):
    """output the summary of the repository"""
    ui.write(b'<?xml version="1.0"?>\n')
    ui.write(b'<rhsummary>\n')
    ui.write(b'<repository root="%s">\n' % _u(repo.root))
    try:
        _tip(ui, repo)
        _tags(ui, repo)
        _branches(ui, repo)
        # TODO: bookmarks in core (Mercurial>=1.8)
    finally:
        ui.write(b'</repository>\n')
        ui.write(b'</rhsummary>\n')

