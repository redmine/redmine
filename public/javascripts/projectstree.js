var m = [ 20, 10, 20, 50 ], w = 900 - m[1] - m[3], h = 800 - m[0] - m[2], i = 0, root;

var tree = d3.layout.tree().size([ h, w ]).separation(function(a, b) {
	return 200;
});

var diagonal = d3.svg.diagonal().projection(function(d) {
	return [ d.y, d.x ];
});

var vis = d3.select("#body").append("svg:svg").attr("width", w + m[1] + m[3])
		.attr("height", h + m[0] + m[2]).append("svg:g").attr("transform",
				"translate(" + m[3] + "," + m[0] + ")");

tobeparsed = d3.select("#jsontree")[0][0].innerHTML;
var root = JSON.parse(tobeparsed);
root.children.sort(function(a, b) {
	if (a.name == "Vertebrate") // vertebrates go first
		return -1;
	if (b.name == "Vertebrate") // vertebrates go first
		return 1;
	return b.name < a.name ? 1 : b.name > a.name ? -1 : 0;
}); // sort everything else alphabetically

root.x0 = h / 2;
root.y0 = 0;

function toggleAll(d) {
	if (d.children) {
		d.children.forEach(toggleAll);
		toggle(d);
	}
}

function makeTree(source)
{
	//dynamic width
	
	  var levelWidth = [1];
	  var childCount = function(level, n) {
	    
	    if(n.children && n.children.length > 0) {
	      if(levelWidth.length <= level + 1) levelWidth.push(0);
	      
	      levelWidth[level+1] += n.children.length;
	      n.children.forEach(function(d) {
	        childCount(level + 1, d);
	      });
	    }
	  };
	  childCount(0, root);  
	  var newHeight = d3.max(levelWidth) * 200; // 20 pixels per line
	  tree = tree.size([newHeight, w]);
	jQuery("svg").get(0).setAttribute("height", Math.max(newHeight, w) + 150);
	
	//end dynamic width
	
	// Compute the new tree layout.
	var nodes = tree.nodes(root).reverse();
	
	// Normalize for fixed-depth.
	nodes.forEach(function(d) {
		d.y = d.depth * 120;
	});

	// Update the nodes…
	var node = vis.selectAll("g.node").data(nodes, function(d) {
		return d.id || (d.id = ++i);
	});

	// Enter any new nodes at the parent's previous position.
	var nodeEnter = node.enter().append("svg:g").attr("class", "node")
		.attr("transform", function(d) { return "translate(" + source.y0 + "," + source.x0 + ")"; })
		.on("click", function(d) {
				toggle(d);
				makeTree(d);
			});
	// .attr(
	// "transform", function(d) {
	// return "translate(" + source.y0 + "," + source.x0 + ")";
	// })

	nodeEnter.append("svg:circle").attr("r", 1e-6).style("fill", function(d) {
		return d._children ? "#8A0" : "#ff6600";
	});

	nodeEnter.append("a").attr("xlink:href", function(d) {
		return d.link;
	}).append("foreignObject").attr("height", "100").attr("width", function(d) {
		return d.name === "Animal Kingdom" ? "200" : "150";
	}).attr("x", function(d) { return d.children || d._children ? 10 : 10; })
    .attr("y", "-10").append("xhtml:body").attr(
			"class",
			function(d) {
				return d.name === "Animal Kingdom" ? "treetextwide"
						: typeof d.link === 'undefined' ? "treetext"
								: "treelinktext";
			}).html(
			function(d) {
				return "<div class="
						+ (d.name === "Animal Kingdom" ? "treetextwide"
								: typeof d.link === 'undefined' ? "treetext"
										: "treelinktext") + ">" + d.name
						+ "</div>";
			})

	// Transition nodes to their new position.
	var nodeUpdate = node.transition().duration(duration).attr("transform",
			function(d) {
				return "translate(" + d.y + "," + d.x + ")";
			});

	nodeUpdate.select("circle").attr("r", 6).style("fill", function(d) {
		return d._children ? "#8A0" : "#ff6600";
	});

	nodeUpdate.select("text").style("fill-opacity", 1);

	// Transition exiting nodes to the parent's new position.
	var nodeExit = node.exit().transition().duration(duration).attr(
			"transform", function(d) {
				return "translate(" + source.y + "," + source.x + ")";
			}).remove();

	nodeExit.select("circle").attr("r", 1e-6);

	nodeExit.select("text").style("fill-opacity", 1e-6);

	// Update the links…
	var link = vis.selectAll("path.link").data(tree.links(nodes), function(d) {
		return d.target.id;
	});

	// Enter any new links at the parent's previous position.
	link.enter().insert("svg:path", "g").attr("class", "link").attr("d",
			function(d) {
				var o = {
					x : source.x0,
					y : source.y0
				};
				return diagonal({
					source : o,
					target : o
				});
			}).transition().duration(duration).attr("d", diagonal);

	// Transition links to their new position.
	link.transition().duration(duration).attr("d", diagonal);

	// Transition exiting nodes to the parent's new position.
	link.exit().transition().duration(duration).attr("d", function(d) {
		var o = {
			x : source.x,
			y : source.y
		};
		return diagonal({
			source : o,
			target : o
		});
	}).remove();

	// Stash the old positions for transition.
	nodes.forEach(function(d) {
		d.x0 = d.x;
		d.y0 = d.y;
	});
}

// Toggle children.
function toggle(d) {
	if (d.children) {
		d._children = d.children;
		d.children = null;
	} else {
		d.children = d._children;
		d._children = null;
	}
}

var timer=null;
var step=0;
var duration = 500;

//7 roaches
function standardOpening()
{
	// Initialize the display to show a few nodes.
	openSpecificTree("Vertebrate","Mammalian","Rodent","Cerebellum","");
}



//This functions opens a specific configuration of the tree, used as backend for the breadcrumb feature
function openSpecificTree(spine,family,specie,brain,cell)
{
	if (root.children != null) 
	{
		root.children.forEach(toggleAll);
	}
	n1=toggleChild(root,spine);
	n2=toggleChild(n1,family);
	n3=toggleChild(n2,specie);
	n4=toggleChild(n3,brain);
	n5=toggleChild(n4,cell);
	makeTree(root);
}

//Opens the child of a node give the name of the child
function toggleChild(node,childname)
{
	if(childname && childname!="")
	{
		if(!node.children)
		{
			toggle(node);
		}
		for(var c in node.children)
		{
			if(node.children[c].name==childname)
			{
				toggle(node.children[c]);
				return node.children[c];
			}
		}
	}
}
