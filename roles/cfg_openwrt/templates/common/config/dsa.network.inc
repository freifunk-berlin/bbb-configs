config device
	option type 'bridge'
	option name 'switch0'

{% for network in networks | selectattr('vid', 'defined') | selectattr('ifname', 'undefined') %}
  {% set portmapping = [] %}
  {% for port in dsa_ports %}
    {% set tagged = not network.get('untagged') %}
    {% set _ = portmapping.append(port ~ (":t" if tagged else ":u")) %}
  {% endfor %}

config bridge-vlan
	option device 'switch0'
	option vlan '{{ network.vid }}'
	option ports '{{ portmapping | join(" ") }}'
{% endfor %}
