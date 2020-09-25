#!/usr/bin/python3

import sys
import matplotlib.pyplot as plt
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import os

dataIndex = 0;
filteredData = [];
for filename in os.listdir('E:\\AlteraProject\\PID_controller\\fpga-spartan3a-velocityScruve\\rawData'):
    print(filename);
    df = pd.read_csv('E:\\AlteraProject\\PID_controller\\fpga-spartan3a-velocityScruve\\rawData\\'+filename);
    df.head();
    #df.columns = ['Samples','Speed']; #Change columns title

    #Shifted Right 8bit data; Format: [Speed, firstbyte][Excitation, first byte][Excitation, second byte][Speed, secondbyte]
    for i in range(1, len(df.index)):
        firstByte = (df.iat[i,1] >> 8) & 0x00FF;
        secondByte = (df.iat[i,1]) & 0x00FF;
        thirdByte = (df.iat[i,2] >> 8) & 0x00FF;
        fourthByte = (df.iat[i,2]) & 0x00FF;
        # print(df.iat[i,1], df.iat[i,2]);
        # print(firstByte, secondByte, thirdByte, fourthByte);
        # print(int.from_bytes([fourthByte,firstByte], "little"));
        # print(int.from_bytes([secondByte,thirdByte], "little"));
        df.iat[i,1] = int.from_bytes([firstByte,fourthByte], "little");
        df.iat[i,2] = int.from_bytes([thirdByte,secondByte], "little");
       # print(df.iat[i,1], df.iat[i,2]);

#    index = 0;
#    for i in range(1,len(df.index)-1):
#        if ( (df.iat[i,1] != 0) ):
#            break;
#        index = index + 1;
#
    # for i in range(2, len(df.index)-1):
        # if ( (df.iat[i,1] > 350) ): # Due to jerk in encoder
            # df.iat[i,1] = 0;
#        if ((abs(df.iat[i-1,1] - df.iat[i,1]) > 10) and (df.iat[i-1,1] > 50)):
#            df.iat[i,1] = df.iat[i-1,1];

#    for i in range(1, len(df.index)-1):
#        if ( ((df.iat[i,2] << 8) & 0xFFFF) == 0xFF00 ):
#            df.iat[i,2] = 0xFFFF;
#        else:
#            df.iat[i,2] = 0;
#
#    endIndex = len(df.index);
#    for i in range(len(df.index)-1,1,-1):
#        if( (df.iat[i,1] != int("0xFF",0)) ):
#            break;
#        endIndex = endIndex-1;

#    print(str(index) + " " + str(endIndex));
    filteredData.append(df[10:]);
    #filteredData[dataIndex] = filteredData[dataIndex].drop(columns=['Samples']);
    filteredData[dataIndex].reset_index(drop=True, inplace= True);
#    filteredData[dataIndex].columns=['Samples','Speed'];
    filteredData[dataIndex].to_csv('E:\\Document\\Probably-thesis\\data\\processed_'+ filename + '.csv');
    #print(filteredData[dataIndex]);
    dataIndex = dataIndex+1;

fig = plt.figure();
i = 0;
line = [];
print(len(filteredData));
for frame in filteredData:
   # fig = px.line(frame, x = 'Samples', y = 'Speed');
   # fig.show();
    line.append(plt.plot(frame['Speed']));
    i = i + 1;
    #print(frame.columns);

for j in range(0, i-1):
    #(line[j]).legend('Data' + j);
    print(line[j]);
plt.show();

