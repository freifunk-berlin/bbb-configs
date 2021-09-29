### .. magic inside

this inventory consists of three inventories.


# base_inventory
the first one prints some ansible-compatible hostlist based on all the folders inside host_vars.


# keyed_groups_stage_1.config
this is a configuration for the "constructed" inventory plugin. it dynamically constructs group memberships based on the host_vars. as the first inventory doesnt output any host & group vars, the constructed inventory has to fetchit on its own. This pretty new feature is available since ansible 2.11 . Its controlled by the "use_vars_plugins" key. Unfortunately its searching for the host&group vars in the folder of the first inventory plugin. As its located here, we need to symlink 'em here in order to allow it accomplishing its job.

.. pretty hacky, but less hacky than before :) ..lets hope ansible  will continue improving 


# keyed_groups_stage_2.config
this is yet another configuration for the "constructed" inventory plugin. in contrast to the first stage its purpose is to dynamically construct even more group memberships based on inherited vars from the previous stage.
