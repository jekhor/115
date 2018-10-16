# 115.бел API

Скрипты для вытаскивания информации с сайта 115.бел

Для доступа спользуется тот же API, который используется на самом сайтe. Описание того, что удалось вытащить из кода сайта — api.txt

В каталоге geojson — вытащенные по запросу getlist данные (запрос используется для показа точек на карте). Описаний заявок там нет.

Для запуска требуются gem-ы rgeo-geojson, rest-client, json, nokogiri

Использование скрипта:

    # Забрать все заявки за октябрь 2018-го
    $ ./115.rb getlist 2018-10 > 2018-10.json

    # То же, в формате GeoJSON
    $ ./115.rb getlist 2018-10 > 2018-10.geojson

    # Забрать все заявки за февраль 2016-го и для каждой заявки получить описание и ответы
    # (Работает медленно!!!)
    $ ./115.rb getlist 2016-02 > 2016-02-details.geojson

    # Получить детальную информацию по заявке
    # problem id — не номер заявки, а ID из URL страницы заявки (они разные!), или из списка, полученного по getlist
    $ ./115.rb problem <problem id>

## Известные проблемы

1. Запрос getlist не отдаёт данные по некоторым месяцам (см. файлы в каталоге geojson). На оригинальном сайте запрос по этим месяцам сделать нельзя.
2. Не реализовано переключение между городами, отдаёт для Минска.

## Полезные ссылки

https://github.com/opendataby/115 — парсинг данных 115.бел сообществом OpenData

## Лицензия
GPLv3
