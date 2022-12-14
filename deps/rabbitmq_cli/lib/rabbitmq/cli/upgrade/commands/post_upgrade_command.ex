## The contents of this file are subject to the Mozilla Public License
## Version 1.1 (the "License"); you may not use this file except in
## compliance with the License. You may obtain a copy of the License
## at https://www.mozilla.org/MPL/
##
## Software distributed under the License is distributed on an "AS IS"
## basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
## the License for the specific language governing rights and
## limitations under the License.
##
## The Original Code is RabbitMQ.
##
## The Initial Developer of the Original Code is GoPivotal, Inc.
## Copyright (c) 2007-2019 Pivotal Software, Inc.  All rights reserved.

defmodule RabbitMQ.CLI.Upgrade.Commands.PostUpgradeCommand do
  alias RabbitMQ.CLI.Core.DocGuide

  @behaviour RabbitMQ.CLI.CommandBehaviour

  use RabbitMQ.CLI.Core.RequiresRabbitAppRunning
  use RabbitMQ.CLI.Core.MergesNoDefaults
  use RabbitMQ.CLI.Core.AcceptsNoPositionalArguments

  def run([], %{node: node_name}) do
    :rabbit_misc.rpc_call(node_name, :rabbit_amqqueue, :rebalance, [:all, ".*", ".*"])
  end

  use RabbitMQ.CLI.DefaultOutput

  def usage, do: "post_upgrade"

  def usage_doc_guides() do
    [
      DocGuide.upgrade()
    ]
  end

  def help_section, do: :upgrade

  def description, do: "Runs post-upgrade tasks"

  def banner([], _) do
    "Executing post upgrade tasks...\n" <>
    "Rebalancing queue masters..."
  end

end
