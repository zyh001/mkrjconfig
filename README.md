# mkrjconfig.sh
网络配置文件批量生成工具

可通过传入的模板文件和参数文件，批量的生成网络配置文件。脚本原理是基于关键字替换，所以可通用的处理**思科、华为、华三、锐捷**等厂商的配置。

### 用法（How_To）

#### 支持的命令：
| 参数                      | 选择 | 解释                                                                           |
| ------------------------- | ---- | ------------------------------------------------------------------------------ |
| `-o`, `--opt-file`        | 必选 | 指定参数文件（可支持xlsx，csv格式的文件）                                      |
| `-t`, `--template-file`   | 必选 | 指定模板文件                                                                   |
| `-O`, `--output-file`     | 可选 | 指定输出文件（不指定默认在当前目录下输出 *./config.out* ）                     |
| `-d`, `--output-dir`      | 可选 | 指定输出文件所在目录（不指定路径默认在当前目录下输出，仅在使用`-s`参数时有效） |
| `-D`, `--disable-rewrite` | 可选 | 如果输出文件已存在，则直接追加不覆盖                                           |
| `-s`, `--suffix`          | 可选 | 指定输出文件名称从参数文件中某列获取（默认为 *file_name* 列）                  |
| `--suffix-index`          | 可选 | 指定输出文件名称后缀，必须与-s参数配合使用（默认为 *.out* ）                   |
| `-l`, `--line`            | 可选 | 指定仅处理参数文件中的前几行（从1开始）                                        |
| `--debug`                 | 保留 | 开启bash调试模式                                                               |

#### 参数详解：
* `-o`指定一个参数文件。可使用`-o filename`, `-o=filename`, `--opt-file filename`以及`--opt-file=filename`传入。以下若包含需要传入文件或参数的均可举一反三地使用。
* `-t`指定模板文件，与`-o`一同组成该脚本所**必须**传入的两个参数。若仅使用这两个参数，则输出的结果直接在命令行呈现。
* `-O`指定输出的文件。若直接键入`-O`不指定文件，则自动在当前文件目录下生成一名为*config.out*的文件。若使用该参数多次执行脚本则会默认覆写该文件，某些情况下可能不希望覆盖，可通过`-D`参数关闭覆写。
* `-s`指定输出文件的名称的命名列。脚本允许通过参数文件内容指定每个文件名称，某些情况下可能不希望生成的所有脚本都位于同一文件内，而是将每个模板文件生成的文件另存为一个文件。可以通过在参数文件内创建一个命名列，并使用该参数，指定该列的标题。若选项后不添加参数，则默认取 *file_name* 列作为命名列，若不存在该列，则将忽略该参数。与`-O`参数互斥。

#### 例子1：

模板文件示例(以锐捷设备，对无线网络进行开局优化为例，配置AP命名，进行基础功率及信道调整), 该文件为纯文本文件[文件名：test.cfg]：
```text
ap-config %AP_Mac%
 ap-name %AP_Name%
 channel %channel_2.4G% radio 1
 power local %power_2.4G% radio 1
 channel %channel_5G% radio 2
 power local %power_5G% radio 2
```
参数文件示例，该文件为表格文件，必须为xlsx或csv格式，否则不识别[文件名：test.xlsx]：
| AP_Mac         | AP_Name              | channel_2.4G | channel_5G | power_2.4G | power_5G |
| -------------- | -------------------- | ------------ | ---------- | ---------- | -------- |
| 5869.6CE9.7C38 | JXL-A_1F-AP720-I_101 | 1            | 149        | 30         | 90       |
| 5869.6CE9.7B70 | JXL-A_1F-AP720-I_102 | 6            | 157        | 30         | 90       |
| 5869.6CE9.7AFD | JXL-A_1F-AP720-I_103 | 11           | 165        | 30         | 90       |
| 5869.6CE9.7B3A | JXL-A_1F-AP720-I_104 | 1            | 149        | 30         | 90       |
| 5869.6CE9.7D1B | JXL-A_1F-AP720-I_105 | 6            | 157        | 30         | 90       |

命令：
```bash
# 所有示例均以参数文件输出前3行为例，故均有-l 3参数
# 直接在命令行打印结果
 $ ./mkrjconfig.sh -o ./test.xlsx -t ./test.cfg -l 3
ap-config 5869.6CE9.7C38
 ap-name JXL-A_1F-AP720-I_101
 channel 1 radio 1
 power local 30 radio 1
 channel 149 radio 2
 power local 90 radio 2
ap-config 5869.6CE9.7B70
 ap-name JXL-A_1F-AP720-I_102
 channel 6 radio 1
 power local 30 radio 1
 channel 157 radio 2
 power local 90 radio 2

# 将输出存为文件
 $ ./mkrjconfig.sh -o ./test.xlsx -t ./test.cfg -l 3 -O ./test.out
 $ cat ./test.out
ap-config 5869.6CE9.7C38
 ap-name JXL-A_1F-AP720-I_101
 channel 1 radio 1
 power local 30 radio 1
 channel 149 radio 2
 power local 90 radio 2
ap-config 5869.6CE9.7B70
 ap-name JXL-A_1F-AP720-I_102
 channel 6 radio 1
 power local 30 radio 1
 channel 157 radio 2
 power local 90 radio 2

# 将输出存为文件，文件命名使用AP_Name列，将文件输出到/tmp文件夹，指定文件后缀为.cfg，若不存在AP_Name列，则会忽略该参数
 $ ./mkrjconfig.sh -o ./test.xlsx -t ./test.cfg -l 3 -O ./test.out -s AP_Name --suffix-index cfg -d /tmp
 $ ls /tmp
JXL-A_1F-AP720-I_101.cfg
JXL-A_1F-AP720-I_102.cfg
 $ cat /tmp/JXL-A_1F-AP720-I_101.cfg
ap-config 5869.6CE9.7C38
 ap-name JXL-A_1F-AP720-I_101
 channel 1 radio 1
 power local 30 radio 1
 channel 149 radio 2
 power local 90 radio 2
```
