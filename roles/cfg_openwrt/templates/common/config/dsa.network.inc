config device
	option type 'bridge'
	option name 'switch0'

{% for network in networks | selectattr('vid', 'defined') | selectattr('ifname', 'undefined') %}
  {% set portmapping = [] %}
  {% for port in dsa_ports %}
    {% set tagged = not network.get('untagged') %}
    {{ portmapping.append(port|string + (":t" if tagged else ":u")) }}
  {%- endfor %}

config bridge-vlan 'vlan_{{ network['vid'] }}'
	option device 'switch0'
	option vlan '{{ network['vid'] }}'
	option ports '{{ portmapping|join(' ') }}'
{% endfor %}
