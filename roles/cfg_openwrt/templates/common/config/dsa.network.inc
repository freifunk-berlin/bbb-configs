config device
	option type 'bridge'
	option name 'switch0'
	option vlan_filtering '1'
  {% set portmapping = [] %}
  {% for port in dsa_ports %}
    {% set _ = portmapping.append(port) %}
  {%- endfor %}
	option ports '{{ portmapping|join(' ') }}'

{% for network in networks | selectattr('vid', 'defined') | selectattr('ifname', 'undefined') %}
  {% set portmapping = [] %}
  {% for port in dsa_ports %}
    {% set tagged = not network.get('untagged') %}
    {{ portmapping.append(port|string + (":t" if tagged else ":u*")) }}
  {%- endfor %}

config device
	option type '8021q'
	option ifname 'switch0'
	option vid '{{ network['vid'] }}'
	option name 'switch0.{{ network['vid'] }}'

config bridge-vlan 'vlan_{{ network['vid'] }}'
	option device 'switch0'
	option vlan '{{ network['vid'] }}'
	option ports '{{ portmapping|join(' ') }}'
{% endfor %}
