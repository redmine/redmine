include KnowledgebaseLinkHelper

module Macros

  Redmine::WikiFormatting::Macros.register do

    #A macro named KB in upper case will be considered as an acronym and will break the macro
    desc "Knowledge base Article link Macro, using the kb# format"
    macro :kb do |obj, args|
      args, options = extract_macro_options(args, :parent)
      raise 'No or bad arguments.' if args.size != 1
      article = KbArticle.find(args.first)
      link_to_article(article)
    end

    desc "Knowledge base Article link Macro, using the article_id# format"
    macro :article_id do |obj, args|
      args, options = extract_macro_options(args, :parent)
      raise 'No or bad arguments.' if args.size != 1
      article = KbArticle.find(args.first)
      link_to_article(article)
    end

    desc "Knowledge base Article link Macro, using the article# format"
    macro :article do |obj, args|
      args, options = extract_macro_options(args, :parent)
      raise 'No or bad arguments.' if args.size != 1
      article = KbArticle.find(args.first)
      link_to_article_with_title(article)
    end

    desc "Knowledge base Category link Macro, using the category# format"
    macro :category do |obj, args|
      args, options = extract_macro_options(args, :parent)
      raise 'No or bad arguments.' if args.size != 1
      category = KbCategory.find(args.first)
      link_to_category_with_title(category)
    end
  end
end
