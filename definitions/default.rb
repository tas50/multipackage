define :multipackage do # ~FC015
  multipackage_definition_impl(params)
end

module MultipackageDefinitionImpl
  def multipackage_definition_impl(params)
    # @todo make sure package_names and versions have the same # of items
    # (unless verison is omitted)
    package_names = []
    if params[:package_name] || params[:name]
      package_names = [params[:package_name] || params[:name]].flatten
    end
    versions = [params[:version]].flatten if params[:version]
    options = params[:options]
    timeout = params[:per_package_timeout]
    action = params[:action] || :install

    t = begin
          # non-delayed eager accumulators like this cannot use recursive search
          #
          # If we are being called from within a custom resource and use
          # recursive search and find a resource in an outer run context, then
          # we always get the use case wrong because if ...
          # - we happen to find a resource "before" us, then it's already been
          #   converged and appending to it will do nothing.
          # - we happen to find a resource "after" us, then the package will be
          #   installed after the entire custom resource breaking ordering.
          #
          run_context.resource_collection.find_local(multipackage_internal: "collected packages #{action}")
        rescue Chef::Exceptions::ResourceNotFound
          multipackage_internal "collected packages #{action}" do
            package_name []
            version []
            action action
          end
        end

    package_names.each_with_index do |package_name, i|
      if t.package_name.include?(package_name)
        # supress CHEF-3694 errors and be more useful about warning if there's only a reason
        if options
          Chef::Log.warn "ignoring options #{options} set on duplicated package #{package_name}"
        end
        if timeout
          Chef::Log.warn "ignoring timeout #{timeout} set on duplicated package #{package_name}"
        end
        next
      end
      t.package_name.push(package_name)
      if versions
        t.version.push versions[i]
      else
        # keep the version array matching the package_name array
        t.version.push nil
      end
    end

    t.options(options) if options
    t.per_package_timeout(timeout) if timeout

    t
  end
end

Chef::Recipe.send(:include, MultipackageDefinitionImpl)
