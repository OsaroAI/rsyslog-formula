{% from "rsyslog/map.jinja" import rsyslog with context %}

{% if rsyslog.exclusive %}
{% for logger in rsyslog.stoplist %}
stoplogger_{{logger}}:
  service.dead:
    - enable: False
    - name: {{ logger }}
    - require_in:
      - service: {{ rsyslog.service }}
{% endfor %}
{% endif %}

remove_old_rsyslog:
  pkg.purged:
    - version: 8.16.0-1ubuntu3.1

rsyslog:
  pkg.installed:
    - name: rsyslog
    - version: 8.2001.0-1
  file.managed:
    - name: {{ rsyslog.config }}
    - template: jinja
    - source: {{ rsyslog.custom_config_template }}
    - context:
        config: {{ rsyslog|json }}

rsyslog_omhttp:
  pkg.installed:
    - name: rsyslog-omhttp
    - version: 8.2001.0-1

service_file:
  file.managed:
    - name: /lib/systemd/system/rsyslog.service
    - source: salt:///rsyslog/service_files/rsyslog.service

rsyslog_service:
  service.running:
    - enable: True
    - name: {{ rsyslog.service }}
    - require:
      - pkg: {{ rsyslog.package }}
    - watch:
      - file: {{ rsyslog.config }}
      - file: /etc/rsyslog.d/*

workdirectory:
  file.directory:
    - name: {{ rsyslog.workdirectory }}
    - user: {{ rsyslog.runuser }}
    - group: {{ rsyslog.rungroup }}
    - mode: 755
    - makedirs: True

{% for filename in salt['pillar.get']('rsyslog:custom', ["50-default.conf"])%}
{% set basename = filename.split('/')|last %}
rsyslog_custom_{{basename}}:
  file.managed:
    - name: {{ rsyslog.custom_config_path }}/{{ basename|replace(".jinja", "") }}
    {% if basename != filename %}
    - source: {{ filename }}
    {% else %}
    - source: salt://rsyslog/files/{{ filename }}
    {% endif %}
    {% if filename.endswith('.jinja') %}
    - template: jinja
    {% endif %}
    - user: {{ rsyslog.runuser }}
    - group: {{ rsyslog.rungroup }}
    - dirmode: 755
    - makedirs: True
    - watch_in:
      - service: {{ rsyslog.service }}
{% endfor %}

{% if 'modules' in rsyslog %}
{% for module in rsyslog.modules %}
rsyslog-{{ module }}:
  pkg.installed:
    - name: {{ rsyslog.module_packages.get(module) }}
{% endfor %}
{% endif %}
