#!/system/bin/sh
# 双指捏合（张开=放大）：MT protocol B，设备 event3 = virtio_input_multi_touch_2
DEV=/dev/input/event3
W=1080
H=2400
MAX=32767

rawx() { echo $(( $1 * MAX / W )); }
rawy() { echo $(( $1 * MAX / H )); }

CX=540
CY=1200
START_HALF=110
END_HALF=380
STEPS=8

i=0
while [ $i -le $STEPS ]; do
  HALF=$(( START_HALF + (END_HALF - START_HALF) * i / STEPS ))
  X1=$(( CX - HALF ))
  X2=$(( CX + HALF ))
  RX1=$(rawx $X1); RX2=$(rawx $X2); RY=$(rawy $CY)

  sendevent $DEV 3 47 0
  sendevent $DEV 3 57 100
  sendevent $DEV 3 53 $RX1
  sendevent $DEV 3 54 $RY
  sendevent $DEV 3 58 700

  sendevent $DEV 3 47 1
  sendevent $DEV 3 57 101
  sendevent $DEV 3 53 $RX2
  sendevent $DEV 3 54 $RY
  sendevent $DEV 3 58 700

  sendevent $DEV 0 0 0
  i=$(( i + 1 ))
done

# 抬起两指
sendevent $DEV 3 47 0
sendevent $DEV 3 57 -1
sendevent $DEV 3 47 1
sendevent $DEV 3 57 -1
sendevent $DEV 0 0 0
echo "pinch done"
