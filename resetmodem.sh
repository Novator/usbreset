#!/bin/bash

#This is script for reset 3G usb modems
#Example of using:
#resetmodem.sh -s -1

CN='Megafon RUS'   #название соединения в NetworkManager'е
MM="Modem"  #маркер модема, можно заменить на "Huawei" или подобное из команды lsusb
EP=2        #число ошибочных пингов из 5
CS=1        #параметр -s CS, число общих повторов (CS=-1 - бесконечно)
PL=25       #макс. длит. пинга
PA="google.ru"    #пингуемый адрес

ps -few | grep "resetmodem.sh"
RC=`ps -few | grep "resetmodem.sh" | wc -l`

if [ "$RC" -gt "4" ]; then
  echo "Уже запущена копия resetmodem.sh"
  exit 1
fi

if [ "$1" == "-s" ] && [ "$2" != "" ]; then
  CS=$(($2));
  echo "Число шагов: $CS"
fi

#BP=0
Step=0

while [ "$Step" != "$CS" ]; do

Step=$(($Step+1))

M=`lsusb | grep $MM`  #строка модема из lsusb

if [ "$M" != "" ]; then   #если модем выбран, можно проверять пинги
  if [ "$CS" != 1 ]; then
    echo "Цикл: $Step/$CS"
  fi
  echo "Делаем пинги до $PA..."
  BP=0
  for i in {1..5}; do #делаем 5 пингов до сервера
    timeout -k 2 -s TERM $(($PL+2)) ping -w $PL -s 8 -c 1 $PA
    Err=$?
    if [ $Err != 0 ]; then
      BP=$(($BP+1))
      echo "ош. $BP пинг:$i/5"
      if [ "$BP" -ge "$EP" ]; then
        break
      fi
    else
      sleep 2
    fi
  done
  echo "потерь пакетов: $BP из $i"

  if [ "$BP" -ge "$EP" ]; then #если потерь пакетов больше 2х
    BP=0
    M=`lsusb | grep $MM`   #на всякий случай снова глянем - вдруг модем выдернули
    echo "Будет сброшен модем:"
    echo $M
    #B="${M:4:3}"
    #D="${M:15:3}"
    M="${M#* }"  #отбрасываем слово с пробелом (Bus)
    B="${M::3}"  #берем 3 цифры
    M="${M#* }"  #отбрасываем слово с пробелом (цифры)
    M="${M#* }"  #отбрасываем слово с пробелом (Device)
    D="${M::3}"  #берем 3 цифры
    echo "на шине [$B], устройство [$D]"
    nmcli con down id "$CN"
    F="/dev/bus/usb/$B/$D"
    echo "полный путь:$F"
    /mnt/data/Personal/C/usbreset/usbreset $F   #сброс usb-устройства (3G модема)!
    /etc/init.d/network-manager restart

    sleep 1
    nmcli con down id "$CN"
    sleep 6
    for i in {1..5}; do     #делаем 5 попыток поднять соединение
      echo "попытка соединения:"$i
      sleep 3
      timeout -k 5 -s TERM 15 nmcli con up id "$CN"
      nmcli con status id "$CN"
      Err=$?
      if [ $Err == 0 ]; then
        echo "Соединение установлено."
        sleep 2
        break
      fi
    done
  fi
else
  echo "Модем [$MM] не найден."
  lsusb
  sleep 1
fi

done