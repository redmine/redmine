/**
 * Redmine - project management software
 * Copyright (C) 2006-  Jean-Philippe Lang
 * This code is released under the GNU General Public License.
 */

function addFile(inputEl, file, eagerUpload) {
  var attachmentsForm = $(inputEl).closest('.attachments_form')
  var attachmentsFields = attachmentsForm.find('.attachments_fields');
  var attachmentsIcons = attachmentsForm.find('.attachments_icons');
  var addAttachment = attachmentsForm.find('.add_attachment');
  var maxFiles = ($(inputEl).attr('multiple') == 'multiple' ? 10 : 1);
  var delIcon = attachmentsIcons.find('svg.svg-del').clone();
  var attachmentIcon = attachmentsIcons.find('svg.svg-attachment').clone();

  if (attachmentsFields.children().length < maxFiles) {
    var attachmentId = addFile.nextAttachmentId++;
    var fileSpan = $('<span>', { id: 'attachments_' + attachmentId });
    var param = $(inputEl).data('param');
    if (!param) {param = 'attachments'};

    fileSpan.append(
        attachmentIcon,
        $('<input>', { type: 'text', 'class': 'icon icon-attachment filename readonly', name: param +'[' + attachmentId + '][filename]', readonly: 'readonly'} ).val(file.name),
        $('<input>', { type: 'text', 'class': 'description', name: param + '[' + attachmentId + '][description]', maxlength: 255, placeholder: $(inputEl).data('description-placeholder') } ).toggle(!eagerUpload),
        $('<input>', { type: 'hidden', 'class': 'token', name: param + '[' + attachmentId + '][token]'} ),
        $('<a>', { href: "#", 'class': 'icon-only icon-del remove-upload' }).append(delIcon).click(removeFile).toggle(!eagerUpload)
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
        fileSpan.find('input.description, a').css('display', 'inline-flex');
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
  if (blob instanceof window.Blob) {
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
  var filesLength = $(inputEl).closest('.attachments_form').find('.attachments_fields').children().length + files.length
  $.each(files, function() {
    if (this.size && maxFileSize != null && this.size > parseInt(maxFileSize)) {sizeExceeded=true;}
  });
  if (sizeExceeded) {
    window.alert(maxFileSizeExceeded);
  } else {
    $.each(files, function() {addFile(inputEl, this, true);});
  }

  if (filesLength > ($(inputEl).attr('multiple') == 'multiple' ? 10 : 1)) {
    window.alert($(inputEl).data('max-number-of-files-message'));
  }
  return sizeExceeded;
}

function handleFileDropEvent(e) {

  $(this).removeClass('fileover');
  blockEventPropagation(e);

  if ($.inArray('Files', e.dataTransfer.types) > -1) {
    handleFileDropEvent.target = e.target;
    if ($(this).hasClass('custom-field-filedroplistner')){
      uploadAndAttachFiles(e.dataTransfer.files, $(this).find('input:file.custom-field-filedrop').first());
    } else {
      uploadAndAttachFiles(e.dataTransfer.files, $(this).find('input:file.filedrop').first());
    }
  }
}
handleFileDropEvent.target = '';

function dragOverHandler(e) {
  $(this).addClass('fileover');
  blockEventPropagation(e);
  e.dataTransfer.dropEffect = 'copy';
}

function dragOutHandler(e) {
  $(this).removeClass('fileover');
  blockEventPropagation(e);
}

function setupFileDrop() {
  if (window.File && window.FileList && window.ProgressEvent && window.FormData) {

    $.event.addProp('dataTransfer');

    $('form div.box:not(.filedroplistner)').has('input:file.filedrop').each(function() {
      $(this).on({
          dragover: dragOverHandler,
          dragleave: dragOutHandler,
          drop: handleFileDropEvent,
          paste: copyImageFromClipboard
      }).addClass('filedroplistner');
    });

    $('form div.box input:file.custom-field-filedrop').closest('p').not('.custom-field-filedroplistner').each(function() {
      $(this).on({
          dragover: dragOverHandler,
          dragleave: dragOutHandler,
          drop: handleFileDropEvent
      }).addClass('custom-field-filedroplistner');
    });
  }
}

function getImageWidth(file) {
  return new Promise((resolve, reject) => {
    if (file.type.startsWith("image/")) {
      const reader = new FileReader();
      reader.onload = function(event) {
        const img = new Image();
        img.onload = function() {
          resolve(img.width);
        };
        img.onerror = reject;
        img.src = event.target.result;
      };
      reader.onerror = reject;
      reader.readAsDataURL(file);
    } else {
      resolve(0);
    }
  });
}

async function getInlineAttachmentMarkup(file) {
  const sanitizedFilename = file.name.replace(/[\/\?\%\*\:\|\"\'<>\n\r]+/g, '_');
  const inlineFilename = encodeURIComponent(sanitizedFilename)
    .replace(/[!()]/g, function(match) { return "%" + match.charCodeAt(0).toString(16) });

  const isFromClipboard = /^clipboard-\d{12}-[a-z0-9]{5}\.\w+$/.test(file.name);
  let imageDisplayWidth;
  if (isFromClipboard) {
    const imageWidth = await getImageWidth(file).catch(() => 0);
    imageDisplayWidth = Math.round(imageWidth / window.devicePixelRatio);
  }
  const hasValidWidth = isFromClipboard && imageDisplayWidth > 0;

  switch (document.body.getAttribute('data-text-formatting')) {
    case 'textile':
      return hasValidWidth
        ? `!{width: ${imageDisplayWidth}px}.${inlineFilename}!`
        : `!${inlineFilename}!`;
    case 'common_mark':
      return hasValidWidth
        ? `<img style="width: ${imageDisplayWidth}px;" src="${inlineFilename}"><br>`
        : `![](${inlineFilename})`;
    default:
      // Text formatting is "none" or unknown
      return '';
  }
}

function addInlineAttachmentMarkup(file) {
  // insert uploaded image inline if dropped area is currently focused textarea
  if($(handleFileDropEvent.target).hasClass('wiki-edit') && $.inArray(file.type, window.wikiImageMimeTypes) > -1) {
    var $textarea = $(handleFileDropEvent.target);
    var cursorPosition = $textarea.prop('selectionStart');
    var description = $textarea.val();
    var newLineBefore = true;
    var newLineAfter = true;
    if(cursorPosition === 0 || description.substr(cursorPosition-1,1).match(/\r|\n/)) {
      newLineBefore = false;
    }
    if(description.substr(cursorPosition,1).match(/\r|\n/)) {
      newLineAfter = false;
    }

    getInlineAttachmentMarkup(file)
      .then(imageMarkup => {
        $textarea.val(
          description.substring(0, cursorPosition)
          + (newLineBefore ? '\n' : '')
          + imageMarkup
          + (newLineAfter ? '\n' : '')
          + description.substring(cursorPosition, description.length)
        );
      })

    // move cursor into next line
    cursorPosition = $textarea.prop('selectionStart');
    $textarea.prop({
      'selectionStart': cursorPosition + 1,
      'selectionEnd': cursorPosition + 1
    });

  }
}

function copyImageFromClipboard(e) {
  if (!$(e.target).hasClass('wiki-edit')) { return; }
  var clipboardData = e.clipboardData || e.originalEvent.clipboardData
  if (!clipboardData) { return; }
  if (clipboardData.types.some(function(t){ return /^text\/plain$/.test(t); })) { return; }

  var files = clipboardData.files
  for (var i = 0 ; i < files.length ; i++) {
    var file = files[i];
    if (file.type.indexOf("image") != -1) {
      var date = new Date();
      var filename = 'clipboard-'
        + date.getFullYear()
        + ('0'+(date.getMonth()+1)).slice(-2)
        + ('0'+date.getDate()).slice(-2)
        + ('0'+date.getHours()).slice(-2)
        + ('0'+date.getMinutes()).slice(-2)
        + '-' + randomKey(5).toLocaleLowerCase()
        + '.' + file.name.split('.').pop();

      // get input file in the closest form
      var inputEl = $(this).closest("form").find('input:file.filedrop');
      handleFileDropEvent.target = e.target;
      addFile(inputEl, new File([file], filename, { type: file.type }), true);
    }
  }
}

$(document).ready(setupFileDrop);
$(document).ready(function(){
  $("input.deleted_attachment").change(function(){
    $(this).parents('.existing-attachment').toggleClass('deleted', $(this).is(":checked"));
  }).change();
});
