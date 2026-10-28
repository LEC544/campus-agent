import { ChatMessage, checkConnection, MAX_CHAT_TURNS, MAX_MESSAGE_LENGTH, sendChat } from '../services/ChatService';

@Entry
@Component
struct Index {
  @State serverUrl: string = 'http://10.0.2.2:8000';
  @State draft: string = '';
  @State messages: ChatMessage[] = [];
  @State pendingText: string = '';
  @State sending: boolean = false;
  @State errorText: string = '';
  @State showSettings: boolean = false;
  @State checking: boolean = false;
  @State connected: boolean = false;
  @State connectionText: string = '配置服务后开始对话';
  private scroller: Scroller = new Scroller();
  private scrollTimer: number = -1;

  aboutToDisappear(): void {
    if (this.scrollTimer >= 0) {
      clearTimeout(this.scrollTimer);
    }
  }

  private scrollToEdge(edge: Edge): void {
    if (this.scrollTimer >= 0) {
      clearTimeout(this.scrollTimer);
    }
    this.scrollTimer = setTimeout(() => {
      this.scroller.scrollEdge(edge);
      this.scrollTimer = -1;
    }, 50);
  }

  private changeServer(value: string): void {
    this.serverUrl = value;
    this.connected = false;
    this.connectionText = '地址已更新，请检查连接';
  }

  private async testConnection(): Promise<void> {
    if (this.checking || this.sending) {
      return;
    }
    this.checking = true;
    this.connectionText = '正在检查连接…';
    try {
      await checkConnection(this.serverUrl);
      this.connected = true;
      this.connectionText = '后端已连接，模型配置由服务端管理';
    } catch (error) {
      this.connected = false;
      const detail = error as Error;
      this.connectionText = detail.message || '连接失败，请检查服务地址';
    } finally {
      this.checking = false;
    }
  }

  private confirmClear(): void {
    if (this.sending || this.checking || this.messages.length === 0) {
      return;
    }
    this.getUIContext().showAlertDialog({
      title: '开始新的对话？',
      message: '当前聊天记录会被清空，输入框中的草稿会保留。',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '新建对话',
        action: () => {
          this.messages = [];
          this.errorText = '';
        }
      }
    });
  }

  private async sendMessage(): Promise<void> {
    const text: string = this.draft.trim();
    if (this.sending || this.checking || text.length === 0) {
      return;
    }
    if (this.messages.length >= MAX_CHAT_TURNS * 2) {
      this.errorText = '当前对话已完成 20 轮，请点击“新对话”后继续';
      return;
    }
    this.sending = true;
    this.errorText = '';
    this.pendingText = text;
    this.draft = '';
    this.scrollToEdge(Edge.Bottom);
    const userMessage: ChatMessage = { role: 'user', content: text };
    const history: ChatMessage[] = this.messages.concat([userMessage]);
    try {
      const reply: ChatMessage = await sendChat(this.serverUrl, history);
      this.messages = history.concat([reply]);
      this.connected = true;
      this.connectionText = '后端已连接';
    } catch (error) {
      const detail = error as Error;
      this.errorText = detail.message || '发送失败，请稍后重试';
      this.draft = text;
    } finally {
      this.sending = false;
      this.pendingText = '';
      this.scrollToEdge(Edge.Bottom);
    }
  }

  @Builder
  connectionSettings() {
    Column({ space: 10 }) {
      Text('服务连接')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#172B3A')
        .width('100%')
      TextInput({ placeholder: '例如 http://192.168.1.10:8000', text: this.serverUrl })
        .fontSize(14)
        .backgroundColor('#F3F6F8')
        .enabled(!this.sending && !this.checking)
        .onChange((value: string) => this.changeServer(value))
      Row({ space: 8 }) {
        Button('Android 模拟器', { type: ButtonType.Normal })
          .fontSize(12)
          .fontColor('#36556A')
          .backgroundColor('#EDF3F6')
          .borderRadius(8)
          .enabled(!this.sending && !this.checking)
          .onClick(() => this.changeServer('http://10.0.2.2:8000'))
        Blank()
        Button(this.checking ? '检查中…' : '检查连接', { type: ButtonType.Normal })
          .fontSize(12)
          .backgroundColor('#176B62')
          .borderRadius(8)
          .enabled(!this.sending && !this.checking)
          .onClick(() => { this.testConnection(); })
      }.width('100%')
      Text('真机请填写电脑的局域网 IP，并确保设备与电脑网络互通。')
        .fontSize(12)
        .fontColor('#70808D')
        .width('100%')
      Text(this.connectionText)
        .fontSize(12)
        .fontColor(this.connected ? '#176B62' : '#70808D')
        .width('100%')
    }
    .padding(16)
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .margin({ bottom: 6 })
  }

  @Builder
  suggestion(title: string, subtitle: string, prompt: string) {
    Row({ space: 12 }) {
      Column({ space: 5 }) {
        Text(title).fontSize(15).fontColor('#243E4D').fontWeight(FontWeight.Medium)
        Text(subtitle).fontSize(12).fontColor('#70808D')
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text('→').fontSize(20).fontColor('#176B62')
    }
    .padding(16)
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(14)
    .onClick(() => {
      this.draft = prompt;
      this.errorText = '';
    })
  }

  @Builder
  welcome() {
    Column({ space: 12 }) {
      Text('你好，同学')
        .fontSize(30)
        .fontWeight(FontWeight.Bold)
        .fontColor('#172B3A')
        .width('100%')
      Text('把问题交给我，我们一步一步来。')
        .fontSize(15)
        .fontColor('#70808D')
        .width('100%')
        .margin({ bottom: 16 })
      this.suggestion('制定复习计划', '从你的时间和学习目标开始',
        '我还有三天准备高数考试，请先问我复习进度和每天可用的时间，再帮我制定计划。')
      this.suggestion('讲清一个知识点', '用例子理解，再继续追问',
        '请用一个生活中的例子解释导数，再给我一道简单的练习题。')
      this.suggestion('试试连续对话', '先告诉我信息，再接着问',
        '请记住：我叫小林，周五有高数考试。请简短确认。')
      Text('点击示例填入输入框，确认后发送。')
        .fontSize(12)
        .fontColor('#8997A1')
        .margin({ top: 6 })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ top: 26, bottom: 20 })
  }

  @Builder
  messageBubble(message: ChatMessage) {
    Row() {
      Column({ space: 6 }) {
        Text(message.role === 'user' ? '你' : '校园助手')
          .fontSize(11)
          .fontColor('#83919B')
        Text(message.content)
          .fontSize(16)
          .fontColor(message.role === 'user' ? '#FFFFFF' : '#243E4D')
          .lineHeight(25)
          .copyOption(CopyOptions.InApp)
          .padding(15)
          .backgroundColor(message.role === 'user' ? '#176B62' : '#FFFFFF')
          .borderRadius(16)
      }
      .alignItems(message.role === 'user' ? HorizontalAlign.End : HorizontalAlign.Start)
      .constraintSize({ maxWidth: '90%' })
    }
    .width('100%')
    .justifyContent(message.role === 'user' ? FlexAlign.End : FlexAlign.Start)
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        Text('AI')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .width(42)
          .height(42)
          .textAlign(TextAlign.Center)
          .backgroundColor('#176B62')
          .borderRadius(14)
        Column({ space: 4 }) {
          Text('校园助手').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#172B3A')
          Text(this.connected ? '后端已连接' : '你的学习对话空间')
            .fontSize(12)
            .fontColor(this.connected ? '#176B62' : '#70808D')
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Button(this.showSettings ? '收起设置' : '连接设置', { type: ButtonType.Normal })
          .fontSize(12)
          .fontColor('#36556A')
          .backgroundColor('#EAF0F3')
          .borderRadius(10)
          .onClick(() => {
            this.showSettings = !this.showSettings;
            if (this.showSettings) {
              this.scrollToEdge(Edge.Top);
            }
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 16 })

      Row() {
        Text('当前对话').fontSize(12).fontColor('#70808D').layoutWeight(1)
        Button('新对话', { type: ButtonType.Normal })
          .fontSize(12)
          .height(30)
          .fontColor('#176B62')
          .backgroundColor('#E6F1ED')
          .borderRadius(8)
          .enabled(!this.sending && !this.checking && this.messages.length > 0)
          .onClick(() => this.confirmClear())
      }
      .padding({ left: 20, right: 20, bottom: 6 })
      .width('100%')

      List({ space: 18, scroller: this.scroller }) {
        if (this.showSettings) {
          ListItem() { this.connectionSettings() }
        }
        if (this.messages.length === 0 && !this.sending) {
          ListItem() { this.welcome() }
        }
        ForEach(this.messages, (message: ChatMessage) => {
          ListItem() { this.messageBubble(message) }
        }, (_message: ChatMessage, index: number) => index.toString())
        if (this.sending) {
          ListItem() { this.messageBubble({ role: 'user', content: this.pendingText }) }
          ListItem() {
            Row({ space: 10 }) {
              LoadingProgress().width(20).height(20).color('#176B62')
              Text('正在整理回答…').fontSize(14).fontColor('#70808D')
            }
            .padding(15)
            .backgroundColor('#FFFFFF')
            .borderRadius(16)
          }
        }
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 20, right: 20, top: 8, bottom: 14 })
      .scrollBar(BarState.Auto)

      Column({ space: 10 }) {
        if (this.errorText.length > 0) {
          Text(this.errorText)
            .fontColor('#A43D38')
            .fontSize(13)
            .width('100%')
            .padding(12)
            .backgroundColor('#FFF1EF')
            .borderRadius(10)
        }
        TextArea({ placeholder: '写下你的问题，或接着上一句聊…', text: this.draft })
          .height(80)
          .fontSize(15)
          .backgroundColor('#F3F6F8')
          .borderRadius(12)
          .maxLength(MAX_MESSAGE_LENGTH)
          .enabled(!this.sending && !this.checking)
          .onChange((value: string) => {
            if (this.draft !== value) {
              this.draft = value;
              this.errorText = '';
            }
          })
        Row({ space: 12 }) {
          Text('已完成 ' + (this.messages.length / 2).toString() + '/20 轮')
            .fontSize(11)
            .fontColor('#8997A1')
            .layoutWeight(1)
          Button(this.sending ? '回答中…' : (this.errorText.length > 0 ? '重试发送' : '发送消息'),
            { type: ButtonType.Normal })
            .fontSize(14)
            .height(40)
            .padding({ left: 22, right: 22 })
            .backgroundColor('#176B62')
            .borderRadius(10)
            .enabled(!this.sending && !this.checking && this.draft.trim().length > 0)
            .onClick(() => { this.sendMessage(); })
        }.width('100%')
        Text('聊天记录仅在当前页面保留')
          .fontSize(11)
          .fontColor('#8997A1')
      }
      .padding({ left: 20, right: 20, top: 14, bottom: 16 })
      .width('100%')
      .backgroundColor('#FFFFFF')
      .borderRadius({ topLeft: 20, topRight: 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F3F6F8')
  }
}
