config device
	option type 'bridge'
	option name 'switch0'

{% for network in networks %}
  {% set portmapping = [] %}
  {% for port in dsa_ports %}
    {% set tagged = not network.get('untagged') %}
    {% if port_untag is defined and network['vid'] in port_untag and port in port_untag[network['vid']] %}
    {% set tagged = false %}
    {% endif %}
    {{ portmapping.append(port|string + (":t" if tagged else "")) }}
  {%- endfor %}

config bridge-vlan
	option device 'switch0'
	option vlan '{{ network['vid'] }}'
	option ports '{{ portmapping|join(' ') }}'
{% endfor %}
