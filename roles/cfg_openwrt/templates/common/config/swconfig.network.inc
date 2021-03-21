config switch
	option name 'switch0'
	option reset '1'
{% if switch_disable_vlan | default(false) %}
	option enable_vlan '0'
{% else %}
	option enable_vlan '1'

  {% for network in networks %}
    {% set portmapping = [] %}
    {% for port in range(switch_ports)|list|difference(switch_ignore_ports) %}
      {% set tagged = not network.get('untagged') or port == switch_int_port %}
      {{ portmapping.append(port|string + ("t" if tagged else "")) }}
    {%- endfor %}

config switch_vlan
	option device 'switch0'
	option vlan '{{ network['vid'] }}'
	option ports '{{ portmapping|join(' ') }}'
  {% endfor %}
{% endif %}


