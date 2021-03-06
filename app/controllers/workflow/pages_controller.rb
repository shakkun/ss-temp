class Workflow::PagesController < ApplicationController
  include Cms::BaseFilter
  include Cms::CrudFilter

  before_action :set_item, only: [:request_update, :approve_update, :remand_update]

  private
    def set_model
       @model = Cms::Page
    end

    def set_item
      @item = @model.find(params[:id]).becomes_with_route
      @item.attributes = fix_params
    end

    def fix_params
      { cur_user: @cur_user, cur_site: @cur_site, cur_node: false }
    end

    def request_approval
      current_level = @item.workflow_current_level
      current_workflow_approvers = @item.workflow_approvers_at(current_level)
      current_workflow_approvers.each do |workflow_approver|
        args = { f_uid: @cur_user._id, t_uid: workflow_approver[:user_id],
                 site: @cur_site, page: @item,
                 url: params[:url], comment: params[:workflow_comment] }
        Workflow::Mailer.request_mail(args).deliver
      end

      @item.set_workflow_approver_state_to_request
      @item.update
    end

  public
    def request_update
      raise "403" unless @item.allowed?(:edit, @cur_user)

      @item.workflow_user_id = @cur_user._id
      @item.workflow_state   = "request"
      @item.workflow_comment = params[:workflow_comment]
      @item.workflow_approvers = params[:workflow_approvers]
      @item.workflow_required_counts = params[:workflow_required_counts]

      if @item.update
        request_approval
        render nothing: true, status: :no_content
      else
        render json: @item.errors.full_messages, status: :unprocessable_entity
      end

    end

    def approve_update
      raise "403" unless @item.allowed?(:approve, @cur_user)

      save_level = @item.workflow_current_level
      @item.update_current_workflow_approver_state(@cur_user, @model::WORKFLOW_STATE_APPROVE, params[:remand_comment])

      if @item.finish_workflow?
        @item.workflow_state = @model::WORKFLOW_STATE_APPROVE
        if @item.release_date
          @item.state = "ready"
        else
          @item.state = "public"
          @item.release_date = nil
        end
      end

      if @item.update
        current_level = @item.workflow_current_level
        if save_level != current_level
          # escalate workflow
          request_approval
        end

        if @item.workflow_state == @model::WORKFLOW_STATE_APPROVE
          # finished workflow
          args = { f_uid: @cur_user._id, t_uid: @item.workflow_user_id,
                   site: @cur_site, page: @item,
                   url: params[:url], comment: params[:remand_comment] }
          Workflow::Mailer.approve_mail(args).deliver
        end
        render nothing: true, status: :no_content
      else
        render json: @item.errors.full_messages, status: :unprocessable_entity
      end
    end

    def remand_update
      raise "403" unless @item.allowed?(:approve, @cur_user)

      @item.workflow_state = @model::WORKFLOW_STATE_REMAND
      @item.update_current_workflow_approver_state(@cur_user, @model::WORKFLOW_STATE_REMAND, params[:remand_comment])

      if @item.update
        if @item.workflow_state == "remand"
          args = { f_uid: @cur_user._id, t_uid: @item.workflow_user_id,
                   site: @cur_site, page: @item,
                   url: params[:url], comment: params[:remand_comment] }
          Workflow::Mailer.remand_mail(args).deliver
        end
        render nothing: true, status: :no_content
      else
        render json: @item.errors.full_messages, status: :unprocessable_entity
      end
    end
end
