REDMINE_EXTENSIONS = {

  toggleDiv: function(el_or_id) {
    var el;
    if (typeof(el_or_id) === 'string') {
        el = $('#' + el_or_id);
    } else {
        el = el_or_id;
    }

    el.toggleClass('collapsed').slideToggle('fast');
  },

  toggleDivAndChangeOpen: function(toggleElementId, changeOpenElement) {
    REDMINE_EXTENSIONS.toggleDiv(toggleElementId);
    $(changeOpenElement).toggleClass('open');
  },

  toggleFilterButtons: function(elButtonsID, elFilter1ID, elFilter2ID)
  {
      var elButtons = $('#' + elButtonsID);
      var elFilter1 = $('#' + elFilter1ID);
      var elFilter2 = $('#' + elFilter2ID);

      if (elFilter1.hasClass('collapsed') && elFilter2.hasClass('collapsed')) {
          elButtons.slideUp('slow');
      } else {
          elButtons.slideDown('slow');
      }
  }

};


// TODO delete - it will be added to extensions
(function($, undefined) {

    var plugin = 'easygrouploader';
    if( $.fn[plugin] )
        return;
    var defaults = {
        next_button_cols: 1,
        load_opened: false,
        load_limit: 25,
        texts: {
            'next': 'Next',
        }
    };

    $.fn[plugin] = function(options, methodParams) {
        $.each($(this), function(idx) {
            var instance = $(this).data('plugin_' + plugin);
            if (!instance) {
                instance = new EasyGroupLoader(this, options);
                $(this).data('plugin_' + plugin, instance);
            } else if (typeof options === 'string') {
                switch (options) {
                    case 'load_groups':
                        if (instance.options.load_opened)
                            instance.load_all_groups();
                }
            }
        });
        return $(this);
    };


    function EasyGroupLoader(elem, options) {
        this.groupsContainer = $(elem);
        this.options = $.extend({}, defaults, options);
        this.loadUrl = options.loadUrl || elem.data('url');
        this.callback = options.callback;
        this.texts = this.options.texts;

        this.init();
    }

    EasyGroupLoader.prototype.init = function()
    {
        var self = this;
        this.groupsContainer.on('click', '.group .expander', function(evt) {
            var $row = $(this).closest('tr.group');
            var group = $row.data('group') || new Group(self, $row);

            if (!group.loaded) {
                if (!group.header.hasClass('group-loaded')) {
                  group.load();
                  group.toggle();
                }
            } else {
                group.toggle();
                if(typeof(self.callback) === 'function')
                    self.callback();
            }

        });
        if (this.options.load_opened)
            this.load_all_groups();
    };

    EasyGroupLoader.prototype.initInlineEdit = function()
    {
        $('.multieditable-container:not(.multieditable-initialized)', this.groupsContainer).each(function() {
            initInlineEditForContainer(this);
        });
        initProjectEdit();
        initEasyAutocomplete();
    };

    EasyGroupLoader.prototype.load_all_groups = function()
    {
        var group;
        var self = this;
        var groups_to_load = [];
        var entity_count = 0;
        $('.group', this.groupsContainer).not('.group-loaded').each(function() {
            group = $(this).data('group') || new Group(self, $(this));
            if (!group.loaded) {
                groups_to_load.push(group);
                entity_count += group.count;
            }
            if (entity_count >= self.options.load_limit) {
                self.load_groups(groups_to_load);
                entity_count = 0;
                groups_to_load = [];
            }
        });
        if (groups_to_load.length > 0) {
            this.load_groups(groups_to_load);
        }
    };

    EasyGroupLoader.prototype.load_groups = function(groups_to_load) {
        var self = this;
        var group_names = groups_to_load.map(function(group) {
            return group.group_value;
        });
        // var url = EPExtensions.setAttrToUrl(, 'group_to_load', group_names);
        $.ajax(this.loadUrl, {
            method: 'GET',
            data: { group_to_load: group_names },
            success: function(data, textStatus, request) {
                var parsed = (typeof data === 'object') ? data : $.parseJSON(data);

                $.each(groups_to_load, function(idx, group) {
                    group.parseData(parsed[group.group_name]);
                    group.toggle();
                });
                self.initInlineEdit();
            }
        });
    };

    function Group(loader, header)
    {
        this.loader = loader;
        this.header = header;
        this.header.data('group', this);
        this.group_name = this.header.data('group-name');
        this.group_value = this.group_name;
        if( $.isArray(this.group_name) ) {
            // potencialne nebezpecne - TODO: vymyslet spravny oddelovac
            this.group_name = '["' + this.group_name.join('", "') + '"]';
        }
        this.count = parseInt(this.header.data('entity-count'));
        this.pages = this.header.data('pages') || 1;
        this.loaded = this.header.hasClass('preloaded');
    }

    Group.prototype.toggle = function() {
        EPExtensions.issuesToggleRowGroup(this.header);
    };

    Group.prototype.load = function() {
        var $hrow = this.header;
        var self = this;

        if (!$hrow.hasClass('group-loaded')) {
            $hrow.addClass('group-loaded');
            $.ajax(this.loader.loadUrl, {
                method: 'GET',
                data: {
                    group_to_load: this.group_value
                },
                success: function(data, textStatus, request) {
                    self.parseData(data);
                    self.loader.initInlineEdit();
                    if(typeof(self.loader.callback) === 'function')
                        self.loader.callback();
                }
            });
        }
    };

    Group.prototype.parseData = function(data) {
        var $hrow = this.header;

        this.rows = $(data);
        $hrow.after(this.rows);
        $hrow.data('group-page', 1);
        this.loaded = true;
        if (this.pages > 1) {
            this.createNextButton();
            // .find doesn't work on this set
            this.rows.filter("tr:last").after(this.next_button);
        }
    };

    Group.prototype.loadNext = function() {
        var $hrow = this.header;
        var page = $hrow.data('group-page') + 1;
        var self = this;

        if (page <= this.pages) {
            $.ajax(this.loader.loadUrl, {
                method: 'GET',
                data: {
                    page: page,
                    group_to_load: this.group_value
                },
                success: function(data, textStatus, request) {
                    self.next_button.before(data);

                    self.loader.initInlineEdit();
                    $hrow.data('group-page', page);
                    if (self.pages === page) {
                        self.next_button.remove();
                    }
                }
            });
        }
    };

    Group.prototype.createNextButton = function() {
        //var next_link_url = EPExtensions.setAttrToUrl(this.loader.loadUrl, 'group_to_load', this.group_value);
        var next_link_url = this.loader.loadUrl + ( this.loader.loadUrl.indexOf('?') >= 0 ? '&' : '?' ) + $.param({group_to_load: this.group_value});
        this.next_link = $('<a>', {href: next_link_url, 'class': 'button'}).text(this.loader.texts['next']).append($("<i>", {"class": "icon-arrow"}));
        this.next_button = $('<tr/>', {'class': 'easy-next-button'}).html($('<td>', {colspan: this.loader.options.next_button_cols, "class": "text-center"}).html(this.next_link));

        var self = this;

        this.next_link.click(function(evt) {
            evt.preventDefault();
            self.loadNext();
        });
    };

})(jQuery);

window.cancelAnimFrame = ( function() {
    return window.cancelAnimationFrame              ||
        window.webkitCancelRequestAnimationFrame    ||
        window.mozCancelRequestAnimationFrame       ||
        window.oCancelRequestAnimationFrame         ||
        window.msCancelRequestAnimationFrame        ||
        clearTimeout;
} )();

window.requestAnimFrame = (function(){
    return  window.requestAnimationFrame   ||
        window.webkitRequestAnimationFrame ||
        window.mozRequestAnimationFrame    ||
        window.oRequestAnimationFrame      ||
        window.msRequestAnimationFrame     ||
        function(callback){
            return window.setTimeout(callback, 1000 / 60);
        };
})();

window.showFlashMessage = (function(type, message, delay){
    var $content = $("#content");
    $content.find(".flash").remove();
    var element = document.createElement("div");
    element.className = 'fixed flash ' + type;
    element.style.position = 'fixed';
    element.style.zIndex = '10001';
    element.style.right = '5px';
    element.style.top = '5px';
    element.setAttribute("onclick", "closeFlashMessage($(this))");
    var close = document.createElement("a");
    close.className = 'icon-close close-icon';
    close.setAttribute("href", "javascript:void(0)");
    close.style.float = 'right';
    close.style.marginLeft = '5px';
    // close.setAttribute("onclick", "closeFlashMessage($(this))");
    var span = document.createElement("span");
    span.innerHTML = message;
    element.appendChild(close);
    element.appendChild(span);
    $content.prepend(element);
    var $element = $(element);
    if(delay){
        setTimeout(function(){
            requestAnimFrame(function(){
                closeFlashMessage($element);
            });
        }, delay);
    }
    return $element;
});

window.closeFlashMessage = (function($element){
    $element.closest('.flash').fadeOut(500, function(){$element.remove();});
});


(function($, undefined) {

    $.widget('easy.easymultiselect', {
        options: {
            source: null,
            rootElement: null, // rootElement in the response from source
            selected: null,
            multiple: true, // multiple values can be selected
            preload: true, // load all possible values
            position: {collision: 'flip'},
            autofocus: false,
            inputName: null, // defaults to element prop name
            render_item: function(ul, item) {
                return $("<li>")
                    .data("item.autocomplete", item)
                    .text(item.label)
                    .appendTo(ul);
            },
            activate_on_input_click: true,
            load_immediately: false,
            show_toggle_button: true,
            select_first_value: true,
            autocomplete_options: {}
        },

        _create: function() {
            this.selectedValues = this.options.selected;
            this._createUI();
            this.expanded = false;
            this.valuesLoaded = false;
            this.afterLoaded = [];
            if ( Array.isArray(this.options.source) ) {
                this.options.preload = true;
                this._initData(this.options.source);
            } else if ( this.options.preload && this.options.load_immediately) {
                this.load();
            } else if ( this.selectedValues ) {
                this.setValue( this.selectedValues );
            }
        },

        _createUI: function() {
            var that = this;
            this.element.wrap('<span class="easy-autocomplete-tag"></span>');
            this.tag = this.element.parent();
            this.inputName = this.options.inputName || this.element.prop('name');

            if( this.options.multiple ) { // multiple values
                this.valueElement = $('<span></span>');
                this.tag.after(this.valueElement);

                if (this.options.show_toggle_button)
                    this._createToggleButton();

                this.valueElement.entityArray({
                    inputNames: this.inputName,
                    afterRemove: function (entity) {
                        that.element.trigger('change');
                    }
                });
            } else { //single value
                this.valueElement = $('<input>', {type: 'hidden', name: this.inputName});
                this.element.after(this.valueElement);
            }

            this._createAutocomplete();
            if( !this.options.multiple ) {
                this.element.css('margin-right', 0);
            }
        },

        _createToggleButton: function() {
            var that = this;
            this.link_ac_toggle = $('<a>').attr('class', 'icon icon-add clear-link');
            this.link_ac_toggle.click(function(evt) {
                var $elem = $(this);
                evt.preventDefault();
                that.load(function(){
                    select = $('<select>').prop('multiple', true).prop('size', 5).prop('name', that.inputName);
                    $.each(that.possibleValues, function(i, v) {
                        option = $('<option>').prop('value', v.id).text(v.value);
                        option.prop('selected', that.getValue().indexOf(v.id) > -1);
                        select.append(option);
                    });
                    $container = $elem.closest('.easy-multiselect-tag-container');
                    $container.find(':input').prop('disabled', true);
                    $container.children().hide();
                    $container.append(select);
                    that.valueElement = select;
                    that.expanded = true;
                });
            });
            this.element.parent().addClass('input-append');
            this.element.after(this.link_ac_toggle);
        },

        _createAutocomplete: function() {
            var that = this;

            that.element.autocomplete($.extend({
                source: function(request, response) {
                    if( that.options.preload ) {
                        that.load(function(){
                            var matcher = new RegExp($.ui.autocomplete.escapeRegex(request.term), "i");
                            response($.grep(that.possibleValues, function(val, i) {
                                return ( !request.term || matcher.test(val.value) );
                            }));
                        }, function(){
                            response();
                        });
                    } else { // asking server everytime
                        if( typeof that.options.source == 'function' ) {
                            that.options.source(function(json){
                                response(that.options.rootElement ? json[that.options.rootElement] : json);
                            });
                        } else {
                            $.getJSON(that.options.source, {
                                term: request.term
                            }, function(json) {
                                response(that.options.rootElement ? json[that.options.rootElement] : json);
                            });
                        }
                    }
                },
                minLength: 0,
                select: function(event, ui) {
                    that.selectValue(ui.item)
                    return false;
                },
                change: function(event, ui) {
                    if (!ui.item) {
                        $(this).val('');
                        if( !that.options.multiple ) {
                            that.valueElement.val('');
                            that.valueElement.change();
                        }
                    }
                },
                position: this.options.position,
                autoFocus: this.options.autofocus
            }, this.options.autocomplete_options)).data("ui-autocomplete")._renderItem = this.options.render_item;

            this.element.click(function() {
                $(this).select();
            });
            if( this.options.activate_on_input_click ) {
                this.element.on('click', function() {
                    if(!that.options.preload)
                        that.element.focus().val('');
                    that.element.trigger('keydown');
                    that.element.autocomplete("search", that.element.val());
                });
            }

            $("<button type='button'>&nbsp;</button>")
                .attr("tabIndex", -1)
                .insertAfter(that.element)
                .button({
                    icons: {
                        primary: "ui-icon-triangle-1-s"
                    },
                    text: false
                })
                .removeClass("ui-corner-all")
                .addClass("ui-corner-right ui-button-icon")
                .css('font-size', '10px')
                .css('margin-left', -1)
                .click(function() {
                    if (that.element.autocomplete("widget").is(":visible")) {
                        that.element.autocomplete("close");
                        that.element.blur();
                        return;
                    }
                    $(this).blur();
                    if(!that.options.preload)
                        that.element.focus().val('');
                    that.element.trigger('keydown');
                    that.element.autocomplete("search", that.element.val());
                });
        },

        _formatData: function(data) {
            return $.map(data, function(elem, i){
                var id, value;
                if (elem instanceof Array) {
                  value = elem[0];
                  id = elem[1];
                } else if (elem instanceof Object) {
                  value = elem.value;
                  id = elem.id;
                } else {
                  id = value = elem;
              }
              return {value: value, id: id};
            });
        },

        _initData: function(data) {
            this.possibleValues = this._formatData(data);
            this.valuesLoaded = true;

            this.selectedValues = this.selectedValues ? this.selectedValues : [];
            if( this.selectedValues.length == 0 && this.options.preload && this.options.select_first_value && this.possibleValues.length > 0 ) {
                this.selectedValues.push(this.possibleValues[0]['id'])
            }

            this.setValue(this.selectedValues);
        },

        load: function(success, fail) {
            var that = this;
            if( this.valuesLoaded ) {
                if( typeof success === 'function' )
                    success();
                return;
            }

            if( typeof success === 'function' )
                this.afterLoaded.push(success);

            if( this.loading )
                return;

            this.loading = true;
            function successFce(json, status, xhr) {
                var data = that.options.rootElement ? json[that.options.rootElement] : json
                if( !data && window.console  ) {
                    console.warn('Data could not be loaded! Please check the datasource.');
                    data = [];
                }
                that._initData(data);
                for (var i = that.afterLoaded.length - 1; i >= 0; i--) {
                    that.afterLoaded[i].call(that);
                }
                that.loading = false;
            }
            if( typeof this.options.source === 'function' ) {
                this.options.source(successFce);
            } else {
                $.ajax(this.options.source, {
                    dataType: 'json',
                    success: successFce,
                    error: fail
                }).always(function(){
                    that.loading = false; //even if ajax fails
                });
            }
        },

        selectValue: function(value) {
            if( this.options.multiple ) {
                this.valueElement.entityArray('add', {
                    id: value.id,
                    name: value.value
                });
                this.element.trigger('change');
                this.element.val('');
            } else {
                this.element.val(value.value);
                this.valueElement.val(value.id);
                this.valueElement.change();
                this.element.change();
            }
        },

        setValue: function(values) {
            var that = this;
            if( typeof values === 'undefined' || !values )
                return false;

            if( this.options.preload ) {
                this.load(function(){
                    if( that.options.multiple ) {
                        that.valueElement.entityArray('clear');
                    }
                    that._setValues(values);
                });
            } else {
                if( that.options.multiple ) {
                    that.valueElement.entityArray('clear');
                }
                that._setValues(values);
            }
        },

        _setValues: function(values) {
            var selected = [];

            if( values.length == 0 )
                return false;

            // allows the combination of only id values and values with label
            for (var i = values.length - 1; i >= 0; i--) {
                var identifier, label;
                if( values[i] instanceof Object && !Array.isArray(values[i]) && values[i] !== null ) {
                    selected.push( values[i] );
                } else if( this.options.preload && Array.isArray(this.possibleValues) )  {
                    for(var j = this.possibleValues.length - 1; j >= 0; j-- ) {
                        if ( values[i] == this.possibleValues[j].id || values[i] == this.possibleValues[j].id.toString() ) {
                            selected.push(this.possibleValues[j]);
                            break;
                        }
                    }
                } else {
                    selected.push( {id: values[i], value: values[i]} );
                }
            }
            for (var i = selected.length - 1; i >= 0; i--) {
                if(this.options.multiple) {
                    this.valueElement.entityArray('add', { id: selected[i].id, name: selected[i].value });
                } else {
                    this.element.val(selected[i].value);
                    this.valueElement.val(selected[i].id);
                }
            }
        },

        getValue: function(with_label) {
            var result;
            if ( this.options.multiple && !this.expanded ) {
                result = this.valueElement.entityArray('getValue'); // entityArray
            } else if ( this.options.multiple ) {
                result = this.valueElement.val(); // select multiple=true
            } else {
                result = [this.valueElement.val()]; // hidden field
            }
            if( with_label ) {
                result = this.possibleValues.filter(function(el) {
                    return result.indexOf( el.id ) >= 0;
                });
            }
            return result;
        }

    });

})(jQuery);
