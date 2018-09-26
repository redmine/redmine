/* Redmine - project management software
   Copyright (C) 2006-2017  Jean-Philippe Lang */

function addFile(inputEl, file, eagerUpload) {
  var attachmentsFields = $(inputEl).closest('.attachments_form').find('.attachments_fields');
  var addAttachment = $(inputEl).closest('.attachments_form').find('.add_attachment');
  var maxFiles = ($(inputEl).attr('multiple') == 'multiple' ? 10 : 1);

  if (attachmentsFields.children().length < maxFiles) {
    var attachmentId = addFile.nextAttachmentId++;
    var fileSpan = $('<span>', { id: 'attachments_' + attachmentId });
    var param = $(inputEl).data('param');
    if (!param) {param = 'attachments'};

    fileSpan.append(
        $('<input>', { type: 'text', 'class': 'icon icon-attachment filename readonly', name: param +'[' + attachmentId + '][filename]', readonly: 'readonly'} ).val(file.name),
        $('<input>', { type: 'text', 'class': 'description', name: param + '[' + attachmentId + '][description]', maxlength: 255, placeholder: $(inputEl).data('description-placeholder') } ).toggle(!eagerUpload),
        $('<input>', { type: 'hidden', 'class': 'token', name: param + '[' + attachmentId + '][token]'} ),
        $('<a>&nbsp</a>').attr({ href: "#", 'class': 'icon-only icon-del remove-upload' }).click(removeFile).toggle(!eagerUpload)
    ).appendTo(attachmentsFields);

    if ($(inputEl).data('description') == 0) {
      fileSpan.find('input.description').remove();
    }

    if(eagerUpload) {
      ajaxUpload(file, attachmentId, fileSpan, inputEl);
    }

    addAttachment.toggle(attachmentsFields.children().length < maxFiles);
    return attachmentId;
  }
  return null;
}

addFile.nextAttachmentId = 1;

function ajaxUpload(file, attachmentId, fileSpan, inputEl) {

  function onLoadstart(e) {
    fileSpan.removeClass('ajax-waiting');
    fileSpan.addClass('ajax-loading');
    $('input:submit', $(this).parents('form')).attr('disabled', 'disabled');
  }

  function onProgress(e) {
    if(e.lengthComputable) {
      this.progressbar( 'value', e.loaded * 100 / e.total );
    }
  }

  function actualUpload(file, attachmentId, fileSpan, inputEl) {

    ajaxUpload.uploading++;

    uploadBlob(file, $(inputEl).data('upload-path'), attachmentId, {
        loadstartEventHandler: onLoadstart.bind(progressSpan),
        progressEventHandler: onProgress.bind(progressSpan)
      })
      .done(function(result) {
        addInlineAttachmentMarkup(file);
        progressSpan.progressbar( 'value', 100 ).remove();
        fileSpan.find('input.description, a').css('display', 'inline-block');
      })
      .fail(function(result) {
        progressSpan.text(result.statusText);
      }).always(function() {
        ajaxUpload.uploading--;
        fileSpan.removeClass('ajax-loading');
        var form = fileSpan.parents('form');
        if (form.queue('upload').length == 0 && ajaxUpload.uploading == 0) {
          $('input:submit', form).removeAttr('disabled');
        }
        form.dequeue('upload');
      });
  }

  var progressSpan = $('<div>').insertAfter(fileSpan.find('input.filename'));
  progressSpan.progressbar();
  fileSpan.addClass('ajax-waiting');

  var maxSyncUpload = $(inputEl).data('max-concurrent-uploads');

  if(maxSyncUpload == null || maxSyncUpload <= 0 || ajaxUpload.uploading < maxSyncUpload)
    actualUpload(file, attachmentId, fileSpan, inputEl);
  else
    $(inputEl).parents('form').queue('upload', actualUpload.bind(this, file, attachmentId, fileSpan, inputEl));
}

ajaxUpload.uploading = 0;

function removeFile() {
  $(this).closest('.attachments_form').find('.add_attachment').show();
  $(this).parent('span').remove();
  return false;
}

function uploadBlob(blob, uploadUrl, attachmentId, options) {

  var actualOptions = $.extend({
    loadstartEventHandler: $.noop,
    progressEventHandler: $.noop
  }, options);

  uploadUrl = uploadUrl + '?attachment_id=' + attachmentId;
  if (blob instanceof window.File) {
    uploadUrl += '&filename=' + encodeURIComponent(blob.name);
    uploadUrl += '&content_type=' + encodeURIComponent(blob.type);
  }

  return $.ajax(uploadUrl, {
    type: 'POST',
    contentType: 'application/octet-stream',
    beforeSend: function(jqXhr, settings) {
      jqXhr.setRequestHeader('Accept', 'application/js');
      // attach proper File object
      settings.data = blob;
    },
    xhr: function() {
      var xhr = $.ajaxSettings.xhr();
      xhr.upload.onloadstart = actualOptions.loadstartEventHandler;
      xhr.upload.onprogress = actualOptions.progressEventHandler;
      return xhr;
    },
    data: blob,
    cache: false,
    processData: false
  });
}

function addInputFiles(inputEl) {
  var attachmentsFields = $(inputEl).closest('.attachments_form').find('.attachments_fields');
  var addAttachment = $(inputEl).closest('.attachments_form').find('.add_attachment');
  var clearedFileInput = $(inputEl).clone().val('');
  var sizeExceeded = false;
  var param = $(inputEl).data('param');
  if (!param) {param = 'attachments'};

  if ($.ajaxSettings.xhr().upload && inputEl.files) {
    // upload files using ajax
    sizeExceeded = uploadAndAttachFiles(inputEl.files, inputEl);
    $(inputEl).remove();
  } else {
    // browser not supporting the file API, upload on form submission
    var attachmentId;
    var aFilename = inputEl.value.split(/\/|\\/);
    attachmentId = addFile(inputEl, { name: aFilename[ aFilename.length - 1 ] }, false);
    if (attachmentId) {
      $(inputEl).attr({ name: param + '[' + attachmentId + '][file]', style: 'display:none;' }).appendTo('#attachments_' + attachmentId);
    }
  }

  clearedFileInput.prependTo(addAttachment);
}

function uploadAndAttachFiles(files, inputEl) {

  var maxFileSize = $(inputEl).data('max-file-size');
  var maxFileSizeExceeded = $(inputEl).data('max-file-size-message');

  var sizeExceeded = false;
  $.each(files, function() {
    if (this.size && maxFileSize != null && this.size > parseInt(maxFileSize)) {sizeExceeded=true;}
  });
  if (sizeExceeded) {
    window.alert(maxFileSizeExceeded);
  } else {
    $.each(files, function() {addFile(inputEl, this, true);});
  }
  return sizeExceeded;
}

function handleFileDropEvent(e) {

  $(this).removeClass('fileover');
  blockEventPropagation(e);

  if ($.inArray('Files', e.dataTransfer.types) > -1) {
    handleFileDropEvent.target = e.target;
    uploadAndAttachFiles(e.dataTransfer.files, $('input:file.filedrop').first());
  }
}
handleFileDropEvent.target = '';

function dragOverHandler(e) {
  $(this).addClass('fileover');
  blockEventPropagation(e);
}

function dragOutHandler(e) {
  $(this).removeClass('fileover');
  blockEventPropagation(e);
}

function setupFileDrop() {
  if (window.File && window.FileList && window.ProgressEvent && window.FormData) {

    $.event.fixHooks.drop = { props: [ 'dataTransfer' ] };

    $('form div.box:not(.filedroplistner)').has('input:file.filedrop').each(function() {
      $(this).on({
          dragover: dragOverHandler,
          dragleave: dragOutHandler,
          drop: handleFileDropEvent
      }).addClass('filedroplistner');
    });
  }
}

function addInlineAttachmentMarkup(file) {
  // insert uploaded image inline if dropped area is currently focused textarea
  if($(handleFileDropEvent.target).hasClass('wiki-edit') && $.inArray(file.type, window.wikiImageMimeTypes) > -1) {
    var $textarea = $(handleFileDropEvent.target);
    var cursorPosition = $textarea.prop('selectionStart');
    var description = $textarea.val();
    var sanitizedFilename = file.name.replace(/[\/\?\%\*\:\|\"\'<>\n\r]+/, '_');
    var inlineFilename = encodeURIComponent(sanitizedFilename)
      .replace(/[!()]/g, function(match) { return "%" + match.charCodeAt(0).toString(16) });
    var newLineBefore = true;
    var newLineAfter = true;
    if(cursorPosition === 0 || description.substr(cursorPosition-1,1).match(/\r|\n/)) {
      newLineBefore = false;
    }
    if(description.substr(cursorPosition,1).match(/\r|\n/)) {
      newLineAfter = false;
    }

    $textarea.val(
      description.substring(0, cursorPosition)
      + (newLineBefore ? '\n' : '')
      + inlineFilename
      + (newLineAfter ? '\n' : '')
      + description.substring(cursorPosition, description.length)
    );

    $textarea.prop({
      'selectionStart': cursorPosition + newLineBefore,
      'selectionEnd': cursorPosition + inlineFilename.length + newLineBefore
    });
    $textarea.parents('.jstBlock')
      .find('.jstb_img').click();

    // move cursor into next line
    cursorPosition = $textarea.prop('selectionStart');
    $textarea.prop({
      'selectionStart': cursorPosition + 1,
      'selectionEnd': cursorPosition + 1
    });

  }
}

$(document).ready(setupFileDrop);
$(document).ready(function(){
  $("input.deleted_attachment").change(function(){
    $(this).parents('.existing-attachment').toggleClass('deleted', $(this).is(":checked"));
  }).change();
});
