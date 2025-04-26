{% if mt7530_eee_bug is defined and mt7530_eee_bug %}
  {% if dsa_ports is defined %}
    {% for port in dsa_ports %}
config device '{{ port }}'
  option name '{{ port }}'
  option eee '0'

    {% endfor %}
  {% else %}
config device '{{ int_port }}'
  option name '{{ int_port }}'
  option eee '0'

  {% endif %}
{% endif %}
