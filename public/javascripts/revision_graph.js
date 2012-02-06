var commits = chunk.commits,
    comms = {},
    pixelsX = [],
    pixelsY = [],
    mmax = Math.max,
    max_rdmid = 0,
    max_space = 0,
    parents = {};
for (var i = 0, ii = commits.length; i < ii; i++) {
    for (var j = 0, jj = commits[i].parents.length; j < jj; j++) {
        parents[commits[i].parents[j][0]] = true;
    }
    max_rdmid = Math.max(max_rdmid, commits[i].rdmid);
    max_space = Math.max(max_space, commits[i].space);
}

for (i = 0; i < ii; i++) {
    if (commits[i].scmid in parents) {
        commits[i].isParent = true;
    }
    comms[commits[i].scmid] = commits[i];
}
var colors = ["#000"];
for (var k = 0; k < max_space; k++) {
    colors.push(Raphael.getColor());
}

function branchGraph(holder) {
    var xstep = 20;
    var ystep = $$('tr.changeset')[0].getHeight();
    var ch, cw;
    cw = max_space * xstep + xstep;
    ch = max_rdmid * ystep + ystep;
    var r = Raphael("holder", cw, ch),
        top = r.set();
    var cuday = 0, cumonth = "";

    for (i = 0; i < ii; i++) {
        var x, y;
        y = 10 + ystep *(max_rdmid - commits[i].rdmid);
        x = 3 + xstep * commits[i].space;
        var stroke = "none";
        r.circle(x, y, 3).attr({fill: colors[commits[i].space], stroke: stroke});
        if (commits[i].refs != null && commits[i].refs != "") {
            var longrefs  = commits[i].refs
            var shortrefs = commits[i].refs;
            if (shortrefs.length > 15) {
              shortrefs = shortrefs.substr(0,13) + "...";
              }
            var t = r.text(x+5,y+5,shortrefs).attr({font: "12px Fontin-Sans, Arial", fill: "#666",
            title: longrefs, cursor: "pointer", rotation: "0"});

            var textbox = t.getBBox();
            t.translate(textbox.width / 2, textbox.height / -3);
         }
        for (var j = 0, jj = commits[i].parents.length; j < jj; j++) {
            var c = comms[commits[i].parents[j][0]];
            var p,arrow;
            if (c) {
                var cy, cx;
                cy = 10 + ystep * (max_rdmid - c.rdmid),
                cx = 3 + xstep * c.space;

                if (c.space == commits[i].space) {
                    p = r.path("M" + x + "," + y + "L" + cx + "," + cy);
                } else {
                    p = r.path(["M", x, y, "C",x,y,x, y+(cy-y)/2,x+(cx-x)/2, y+(cy-y)/2,
                                "C", x+(cx-x)/2,y+(cy-y)/2, cx, cy-(cy-y)/2, cx, cy]);
                }
            } else {
              p = r.path("M" + x + "," + y + "L" + x + "," + ch);
             }
            p.attr({stroke: colors[commits[i].space], "stroke-width": 1.5});
         }
        (function (c, x, y) {
            top.push(r.circle(x, y, 10).attr({fill: "#000", opacity: 0,
                                              cursor: "pointer", href: commits[i].href})
              .hover(function () {}, function () {})
              );
        }(commits[i], x, y));
     }
    top.toFront();
    var hw = holder.offsetWidth,
        hh = holder.offsetHeight,
        drag,
        dragger = function (e) {
            if (drag) {
                e = e || window.event;
                holder.scrollLeft = drag.sl - (e.clientX - drag.x);
                holder.scrollTop = drag.st - (e.clientY - drag.y);
            }
        };
    holder.onmousedown = function (e) {
        e = e || window.event;
        drag = {x: e.clientX, y: e.clientY, st: holder.scrollTop, sl: holder.scrollLeft};
        document.onmousemove = dragger;
    };
    document.onmouseup = function () {
        drag = false;
        document.onmousemove = null;
    };
    holder.scrollLeft = cw;
};

Raphael.fn.popupit = function (x, y, set, dir, size) {
    dir = dir == null ? 2 : dir;
    size = size || 5;
    x = Math.round(x);
    y = Math.round(y);
    var bb = set.getBBox(),
        w = Math.round(bb.width / 2),
        h = Math.round(bb.height / 2),
        dx = [0, w + size * 2, 0, -w - size * 2],
        dy = [-h * 2 - size * 3, -h - size, 0, -h - size],
        p = ["M", x - dx[dir], y - dy[dir], "l", -size, (dir == 2) * -size, -mmax(w - size, 0),
             0, "a", size, size, 0, 0, 1, -size, -size,
            "l", 0, -mmax(h - size, 0), (dir == 3) * -size, -size, (dir == 3) * size, -size, 0,
            -mmax(h - size, 0), "a", size, size, 0, 0, 1, size, -size,
            "l", mmax(w - size, 0), 0, size, !dir * -size, size, !dir * size, mmax(w - size, 0),
            0, "a", size, size, 0, 0, 1, size, size,
            "l", 0, mmax(h - size, 0), (dir == 1) * size, size, (dir == 1) * -size, size, 0,
            mmax(h - size, 0), "a", size, size, 0, 0, 1, -size, size,
            "l", -mmax(w - size, 0), 0, "z"].join(","),
        xy = [{x: x, y: y + size * 2 + h},
              {x: x - size * 2 - w, y: y},
              {x: x, y: y - size * 2 - h},
              {x: x + size * 2 + w, y: y}]
              [dir];
    set.translate(xy.x - w - bb.x, xy.y - h - bb.y);
    return this.set(this.path(p).attr({fill: "#234", stroke: "none"})
                     .insertBefore(set.node ? set : set[0]), set);
};

Raphael.fn.popup = function (x, y, text, dir, size) {
    dir = dir == null ? 2 : dir > 3 ? 3 : dir;
    size = size || 5;
    text = text || "$9.99";
    var res = this.set(),
        d = 3;
    res.push(this.path().attr({fill: "#000", stroke: "#000"}));
    res.push(this.text(x, y, text).attr(this.g.txtattr).attr({fill: "#fff", "font-family": "Helvetica, Arial"}));
    res.update = function (X, Y, withAnimation) {
        X = X || x;
        Y = Y || y;
        var bb = this[1].getBBox(),
            w = bb.width / 2,
            h = bb.height / 2,
            dx = [0, w + size * 2, 0, -w - size * 2],
            dy = [-h * 2 - size * 3, -h - size, 0, -h - size],
            p = ["M", X - dx[dir], Y - dy[dir], "l", -size, (dir == 2) * -size,
                 -mmax(w - size, 0), 0, "a", size, size, 0, 0, 1, -size, -size,
                "l", 0, -mmax(h - size, 0), (dir == 3) * -size, -size, (dir == 3) * size, -size,
                 0, -mmax(h - size, 0), "a", size, size, 0, 0, 1, size, -size,
                "l", mmax(w - size, 0), 0, size, !dir * -size, size, !dir * size, mmax(w - size, 0),
                 0, "a", size, size, 0, 0, 1, size, size,
                "l", 0, mmax(h - size, 0), (dir == 1) * size, size, (dir == 1) * -size, size, 0,
                mmax(h - size, 0), "a", size, size, 0, 0, 1, -size, size,
                "l", -mmax(w - size, 0), 0, "z"].join(","),
            xy = [{x: X, y: Y + size * 2 + h},
                  {x: X - size * 2 - w, y: Y},
                  {x: X, y: Y - size * 2 - h},
                  {x: X + size * 2 + w, y: Y}]
                  [dir];
        xy.path = p;
        if (withAnimation) {
            this.animate(xy, 500, ">");
        } else {
            this.attr(xy);
         }
        return this;
     };
    return res.update(x, y);
};
