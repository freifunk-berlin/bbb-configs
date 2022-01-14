config device
	option type 'bridge'
	option name 'switch0'

{% for network in networks %}
  {% set portmapping = [] %}
  {% for port in dsa_ports %}
    {% if wg_wan_if not in port %}
      {% set tagged = not network.get('untagged') %}
      {{ portmapping.append(port|string + (":t" if tagged else "")) }}
    {% endif %}
  {%- endfor %}

config bridge-vlan
	option device 'switch0'
	option vlan '{{ network['vid'] }}'
	option ports '{{ portmapping|join(' ') }}'
{% endfor %}
