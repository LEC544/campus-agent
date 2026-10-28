import { ChatMessage, sendChat } from '../services/ChatService';

@Entry
@Component
struct Index {
  @State serverUrl: string = 'http://10.0.2.2:8000';
  @State draft: string = '';
  @State messages: ChatMessage[] = [];
  @State sending: boolean = false;
  @State errorText: string = '';
  private scroller: Scroller = new Scroller();

  private async sendMessage(): Promise<void> {
    const text: string = this.draft.trim();
    if (this.sending || text.length === 0) {
      return;
    }
    if (this.messages.length >= 40) {
      this.errorText = '已达到 Demo 的 20 轮上限，请清空会话后继续';
      return;
    }
    this.sending = true;
    this.errorText = '';
    const userMessage: ChatMessage = { role: 'user', content: text };
    const history: ChatMessage[] = this.messages.concat([userMessage]);
    try {
      const reply: ChatMessage = await sendChat(this.serverUrl, history);
      this.messages = history.concat([reply]);
      this.draft = '';
      this.scroller.scrollEdge(Edge.Bottom);
    } catch (error) {
      const detail = error as Error;
      this.errorText = detail.message || '连接失败，请检查后端地址、网络和应用网络权限';
    } finally {
      this.sending = false;
    }
  }

  build() {
    Column({ space: 12 }) {
      Row() {
        Text('校园助手 · 多轮对话')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
        Button('清空')
          .enabled(!this.sending && this.messages.length > 0)
          .onClick(() => {
            this.messages = [];
            this.errorText = '';
          })
      }.width('100%')

      TextInput({ placeholder: '后端地址', text: this.serverUrl })
        .enabled(!this.sending)
        .onChange((value: string) => {
          this.serverUrl = value;
        })
      Text('Android 模拟器使用 10.0.2.2；真机填写电脑局域网 IP')
        .fontSize(12)
        .fontColor('#64748B')
        .width('100%')

      List({ space: 12, scroller: this.scroller }) {
        if (this.messages.length === 0) {
          ListItem() {
            Text('先说“请记住：我叫小林，周五有高数考试”，再追问“我叫什么，什么时候考试？”')
              .fontColor('#64748B')
              .padding(16)
          }
        }
        ForEach(this.messages, (message: ChatMessage) => {
          ListItem() {
            Column({ space: 6 }) {
              Text(message.role === 'user' ? '你' : 'DeepSeek')
                .fontSize(12)
                .fontColor('#64748B')
              Text(message.content)
                .fontSize(16)
                .copyOption(CopyOptions.InApp)
                .width('100%')
            }
            .alignItems(HorizontalAlign.Start)
            .padding(14)
            .width('100%')
            .borderRadius(12)
            .backgroundColor(message.role === 'user' ? '#DBEAFE' : '#F1F5F9')
          }
        }, (_message: ChatMessage, index: number) => index.toString())
        if (this.sending) {
          ListItem() {
            Text('正在发送：' + this.draft + '\n\nDeepSeek 正在回复…')
              .fontColor('#64748B')
              .padding(14)
          }
        }
      }
      .layoutWeight(1)
      .width('100%')

      if (this.errorText.length > 0) {
        Text(this.errorText)
          .fontColor('#B91C1C')
          .fontSize(13)
          .width('100%')
      }

      TextArea({ placeholder: '输入消息，支持连续追问…', text: this.draft })
        .height(88)
        .maxLength(16000)
        .enabled(!this.sending)
        .onChange((value: string) => {
          this.draft = value;
        })
      Button(this.sending ? '等待回复…' : '发送')
        .width('100%')
        .enabled(!this.sending && this.draft.trim().length > 0)
        .onClick(() => {
          this.sendMessage();
        })
      Text('本页保留当前对话，退出后不保存 · 已完成 ' +
        (this.messages.length / 2).toString() + '/20 轮')
        .fontSize(12)
        .fontColor('#64748B')
    }
    .padding(20)
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
