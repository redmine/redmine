class QueriesController < ApplicationController
  layout 'base'
  
  def index
    list
    render :action => 'list'
  end

  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify :method => :post, :only => [ :destroy, :create, :update ],
         :redirect_to => { :action => :list }

  def list
    @query_pages, @queries = paginate :queries, :per_page => 10
  end

  def show
    @query = Query.find(params[:id])
  end

  def new
    @query = Query.new(params[:query])
    
    params[:fields].each do |field|
      @query.add_filter(field, params[:operators][field], params[:values][field])
    end if params[:fields]
    
    if request.post? and @query.save
      flash[:notice] = 'Query was successfully created.'
      redirect_to :action => 'list'
    end
  end

  def edit
    @query = Query.find(params[:id])

    if request.post?
      @query.filters = {}
      params[:fields].each do |field|
        @query.add_filter(field, params[:operators][field], params[:values][field])
      end if params[:fields]
      @query.attributes = params[:query]
    
      if @query.save
        flash[:notice] = 'Query was successfully updated.'
        redirect_to :action => 'show', :id => @query
      end
    end
  end

  def destroy
    Query.find(params[:id]).destroy
    redirect_to :action => 'list'
  end
end
