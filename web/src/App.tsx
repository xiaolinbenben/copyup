import { Badge } from "@/components/ui/badge"
import { Button, buttonVariants } from "@/components/ui/button"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion"
import { Kbd } from "@/components/ui/kbd"
import {
  LayeredCard,
  LayeredCardContent,
  LayeredCardHeader,
} from "@/components/ui/layered-card"
import { Marquee, MarqueeItem, MarqueeSeparator } from "@/components/ui/marquee"
import { Sticker } from "@/components/ui/sticker"
import {
  appStoreUrl,
  githubUrl,
  downloadPath,
  privacyPolicyUrl,
  sourceLicenseUrl,
} from "@/site"

const downloadUrl = `${import.meta.env.BASE_URL}${downloadPath}`

const features = [
  {
    title: "历史摊在菜单里",
    body: "复制过的文本和图片留在主菜单。打开就能选，不用再点进一层文件夹。",
  },
  {
    title: "常用的收进收藏",
    body: "还要再用的文本可以收藏。历史和收藏在同一个面板里切换。",
  },
  {
    title: "两个快捷键",
    body: "历史默认是 Control + V，收藏默认是 Control + B。面板出现在鼠标旁边。",
  },
  {
    title: "看清楚再贴",
    body: "文本更大，图片直接预览。同一行可以粘贴、收藏或删除，后两个不会把内容贴出去。",
  },
  {
    title: "内容留在这台 Mac",
    body: "复制的文字、图片和收藏都在这台 Mac 上处理，不会上传到云端。",
  },
  {
    title: "只做 Apple Silicon",
    body: "需要 macOS 13 或更高版本。界面有中文和英文。",
  },
]

const steps = [
  {
    index: "01",
    title: "照常复制",
    body: "文字、链接、图片，还是用原来的方式复制。",
  },
  {
    index: "02",
    title: "按一下打开",
    body: "Control + V 看历史，Control + B 看收藏。",
  },
  {
    index: "03",
    title: "选中就贴回",
    body: "选一条，贴回你正在输入的地方。",
  },
]

const questions = [
  {
    id: "windows",
    question: "它是 Windows 剪切板的 Mac 版吗？",
    answer:
      "定位就是这个。Windows 里用 Win + V 翻刚才复制过的内容；CopyUp 把这件事放在 Mac 菜单栏。另外可以收藏还要用的文本，默认快捷键是 Control + V 和 Control + B。",
  },
  {
    id: "store",
    question: "现在能下载吗？",
    answer:
      "官网版现在可以免费下载。Mac App Store 还没有上架；上架之后，商店版的功能更全。",
  },
  {
    id: "price",
    question: "官网版和 App Store 版有什么不同？",
    answer:
      "官网版免费，保存 10 条历史和 5 条收藏。App Store 版功能更全，历史和收藏都不限制。这个网站不收款。",
  },
  {
    id: "mac",
    question: "哪些 Mac 能用？",
    answer:
      "Apple Silicon 的 Mac，系统为 macOS 13 Ventura 或更高。没有 Intel 版本。",
  },
  {
    id: "privacy",
    question: "复制的内容会上传吗？",
    answer:
      "不会。剪切板内容都在本地处理，不上传到云端。CopyUp 会检查更新，分析和崩溃报告默认打开，可以在设置里关闭。本地记录本身没有加密，密码管理器这类应用建议排除在记录之外。",
  },
  {
    id: "shortcut",
    question: "快捷键能改吗？",
    answer: "能。默认是历史 Control + V，收藏 Control + B。",
  },
]

function DownloadLink({
  size = "lg",
}: {
  size?: "sm" | "default" | "lg" | "xl"
}) {
  return (
    <Button asChild size={size}>
      <a href={downloadUrl}>免费下载</a>
    </Button>
  )
}

function AppStoreLink({
  size = "lg",
  variant = "outline",
}: {
  size?: "sm" | "default" | "lg" | "xl"
  variant?: "default" | "outline"
}) {
  if (!appStoreUrl) {
    return (
      <Button
        type="button"
        size={size}
        variant={variant}
        disabled
        className="disabled:opacity-100"
        title="Mac App Store 尚未上架"
      >
        App Store 即将上架
      </Button>
    )
  }

  return (
    <Button asChild size={size} variant={variant}>
      <a href={appStoreUrl} target="_blank" rel="noreferrer">
        App Store 版
      </a>
    </Button>
  )
}

function App() {
  return (
    <div className="min-h-screen bg-background text-foreground">
      <a
        href="#content"
        className={buttonVariants({
          variant: "outline",
          size: "sm",
          className:
            "sr-only focus:not-sr-only focus:absolute focus:top-3 focus:left-3 focus:z-50",
        })}
      >
        跳到内容
      </a>

      <header className="sticky top-0 z-20 border-b-3 border-foreground bg-background">
        <div className="mx-auto flex max-w-6xl items-center justify-between gap-4 px-4 py-3">
          <a
            href="#top"
            className="flex items-center gap-2 text-xl font-black tracking-tight"
          >
            <img
              src={`${import.meta.env.BASE_URL}favicon.png`}
              alt=""
              width={48}
              height={48}
              className="size-12"
            />
            CopyUp
          </a>
          <nav
            aria-label="页面"
            className="hidden items-center gap-5 text-sm font-bold md:flex"
          >
            <a href="#features">功能</a>
            <a href="#use">怎么用</a>
            <a href="#editions">版本</a>
            <a href="#faq">问题</a>
            <a href="#privacy">隐私</a>
          </nav>
          <DownloadLink size="sm" />
        </div>
      </header>

      <main id="content">
        <section id="top" className="border-b-3 border-foreground">
          <div className="mx-auto grid max-w-6xl items-center gap-10 px-4 pt-12 pb-16 lg:grid-cols-[1.1fr_0.9fr] lg:pt-20 lg:pb-24">
            <div>
              <Sticker
                variant="primary"
                rotation="slight"
                size="lg"
                aria-hidden="true"
                className="normal-case"
              >
                适用于 Mac
              </Sticker>
              <h1 className="mt-6 max-w-3xl text-5xl leading-none font-black tracking-tight sm:text-7xl">
                简单优雅的剪切板工具
              </h1>
              <p className="mt-6 max-w-xl text-lg leading-relaxed font-medium">
                Windows 里按 Win + V，就能翻刚才复制的内容。CopyUp 把这件事放进
                Mac 菜单栏：历史、收藏、粘贴，都在一个面板里。
              </p>
              <div className="mt-8 flex flex-wrap items-center gap-3">
                <DownloadLink size="xl" />
                <AppStoreLink size="xl" />
              </div>
              <p className="mt-4 max-w-xl font-medium">
                官网版免费，保存 10 条历史和 5 条收藏。App Store
                版功能更全，历史和收藏都不限制。
              </p>
              <ul className="mt-8 flex flex-wrap gap-2">
                <li>
                  <Badge variant="secondary">Apple Silicon</Badge>
                </li>
                <li>
                  <Badge variant="accent">macOS 13+</Badge>
                </li>
                <li>
                  <Badge variant="outline">菜单栏</Badge>
                </li>
              </ul>
            </div>

            <LayeredCard
              layers="triple"
              offset="lg"
              layerColor="accent"
              aria-label="CopyUp 菜单示意"
            >
              <LayeredCardHeader className="flex-row items-center justify-between space-y-0">
                <span className="font-black">CopyUp</span>
                <span className="text-xs font-bold">示意</span>
              </LayeredCardHeader>
              <LayeredCardContent className="space-y-3 bg-background p-4">
                <div className="grid grid-cols-2 border-3 border-foreground">
                  <div className="bg-foreground px-3 py-2 text-center text-sm font-black text-background">
                    历史
                  </div>
                  <div className="bg-background px-3 py-2 text-center text-sm font-bold">
                    收藏
                  </div>
                </div>
                <div className="border-3 border-foreground bg-card p-3">
                  <p className="text-xs font-bold">文本</p>
                  <p className="mt-1 font-medium">
                    周五例会改到 3 点，会议室在 2 楼。
                  </p>
                </div>
                <div className="border-3 border-foreground bg-card p-3">
                  <p className="text-xs font-bold">链接</p>
                  <p className="mt-1 font-medium">https://example.com/spec</p>
                </div>
                <div className="border-3 border-foreground bg-secondary p-3">
                  <p className="text-xs font-bold">图片</p>
                  <div className="mt-2 h-16 border-3 border-foreground bg-accent" />
                </div>
                <div className="flex flex-wrap items-center gap-2 pt-1 text-sm font-bold">
                  <span>历史</span>
                  <Kbd size="lg">Ctrl</Kbd>
                  <Kbd size="lg">V</Kbd>
                  <span className="ml-2">收藏</span>
                  <Kbd size="lg">Ctrl</Kbd>
                  <Kbd size="lg">B</Kbd>
                </div>
              </LayeredCardContent>
            </LayeredCard>
          </div>
        </section>

        <Marquee speed="slow">
          <MarqueeItem className="normal-case">复制</MarqueeItem>
          <MarqueeSeparator />
          <MarqueeItem className="normal-case">历史</MarqueeItem>
          <MarqueeSeparator />
          <MarqueeItem className="normal-case">收藏</MarqueeItem>
          <MarqueeSeparator />
          <MarqueeItem className="normal-case">粘贴</MarqueeItem>
          <MarqueeSeparator />
          <MarqueeItem className="normal-case">留在这台 Mac</MarqueeItem>
          <MarqueeSeparator />
        </Marquee>

        <section id="features" className="mx-auto max-w-6xl px-4 py-16">
          <div className="max-w-2xl">
            <h2 className="text-4xl font-black tracking-tight">
              少一步，就能贴回去。
            </h2>
            <p className="mt-4 text-lg font-medium">
              CopyUp
              是菜单栏里的剪切板。它不改你复制的习惯，只把刚用过的内容留在手边。
            </p>
          </div>
          <div className="mt-8 grid gap-4 md:grid-cols-2 lg:grid-cols-3">
            {features.map((feature) => (
              <Card key={feature.title}>
                <CardHeader>
                  <CardTitle className="normal-case">{feature.title}</CardTitle>
                </CardHeader>
                <CardContent>
                  <CardDescription className="text-base font-medium text-foreground">
                    {feature.body}
                  </CardDescription>
                </CardContent>
              </Card>
            ))}
          </div>
        </section>

        <section id="use" className="border-y-3 border-foreground bg-accent">
          <div className="mx-auto max-w-6xl px-4 py-16">
            <h2 className="text-4xl font-black tracking-tight">你已经会用。</h2>
            <div className="mt-8 grid gap-4 lg:grid-cols-2">
              <Card role="region" aria-label="Windows 自带剪切板">
                <CardHeader>
                  <CardTitle className="normal-case">Windows</CardTitle>
                </CardHeader>
                <CardContent className="space-y-3 text-lg font-bold">
                  <p className="flex items-center gap-2">
                    <Kbd size="lg">Win</Kbd>
                    <span>+</span>
                    <Kbd size="lg">V</Kbd>
                  </p>
                  <p>翻系统自带的剪切板历史。</p>
                </CardContent>
              </Card>
              <Card role="region" aria-label="CopyUp 快捷键">
                <CardHeader>
                  <CardTitle className="normal-case">Mac 上的 CopyUp</CardTitle>
                </CardHeader>
                <CardContent className="space-y-3 text-lg font-bold">
                  <p className="flex flex-wrap items-center gap-2">
                    <Kbd size="lg">Ctrl</Kbd>
                    <Kbd size="lg">V</Kbd>
                    <span>历史</span>
                  </p>
                  <p className="flex flex-wrap items-center gap-2">
                    <Kbd size="lg">Ctrl</Kbd>
                    <Kbd size="lg">B</Kbd>
                    <span>收藏</span>
                  </p>
                </CardContent>
              </Card>
            </div>
            <ol className="mt-4 grid gap-4 md:grid-cols-3">
              {steps.map((step) => (
                <li key={step.index}>
                  <Card className="h-full">
                    <CardHeader>
                      <p className="font-mono text-sm font-bold">
                        {step.index}
                      </p>
                      <CardTitle className="normal-case">
                        {step.title}
                      </CardTitle>
                    </CardHeader>
                    <CardContent>
                      <p className="font-medium">{step.body}</p>
                    </CardContent>
                  </Card>
                </li>
              ))}
            </ol>
          </div>
        </section>

        <section id="editions" className="mx-auto max-w-6xl px-4 py-16">
          <h2 className="text-4xl font-black tracking-tight">两个版本。</h2>
          <div className="mt-8 grid gap-4 md:grid-cols-2">
            <Card>
              <CardHeader>
                <CardTitle className="normal-case">官网版 · 免费</CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <p className="font-medium">保存 10 条历史，5 条收藏。</p>
                <DownloadLink />
              </CardContent>
            </Card>
            <Card>
              <CardHeader>
                <CardTitle className="normal-case">
                  App Store 版 · 功能更全
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <p className="font-medium">历史和收藏都不限制。</p>
                <AppStoreLink />
              </CardContent>
            </Card>
          </div>
        </section>

        <section
          id="privacy"
          className="border-y-3 border-foreground bg-secondary"
        >
          <div className="mx-auto max-w-6xl px-4 py-16">
            <h2 className="max-w-3xl text-4xl font-black tracking-tight">
              剪切板内容均本地处理，不上传云端。
            </h2>
            <p className="mt-4 max-w-2xl text-lg font-medium">
              你复制的文字、图片和收藏只留在这台 Mac 上。CopyUp
              不会把这些内容发送到服务器或云端。
            </p>
          </div>
        </section>

        <section id="faq" className="mx-auto max-w-3xl px-4 py-16">
          <h2 className="text-4xl font-black tracking-tight">常见问题</h2>
          <Accordion type="single" collapsible className="mt-8">
            {questions.map((item) => (
              <AccordionItem key={item.id} value={item.id}>
                <AccordionTrigger className="text-left normal-case">
                  {item.question}
                </AccordionTrigger>
                <AccordionContent className="text-base leading-relaxed font-medium">
                  {item.answer}
                </AccordionContent>
              </AccordionItem>
            ))}
          </Accordion>
        </section>

        <section className="border-y-3 border-foreground bg-primary">
          <div className="mx-auto flex max-w-6xl flex-col items-start gap-6 px-4 py-16">
            <h2 className="max-w-2xl text-4xl font-black tracking-tight sm:text-5xl">
              先下载免费的官网版。
            </h2>
            <p className="max-w-xl text-lg font-bold">
              官网版现在就能安装。App Store
              版上架后功能更全，历史和收藏都不限制。
            </p>
            <div className="flex flex-wrap gap-3">
              <DownloadLink size="xl" />
              <AppStoreLink size="xl" />
            </div>
          </div>
        </section>
      </main>

      <footer className="mx-auto flex max-w-6xl flex-col gap-4 px-4 py-8 text-sm font-medium">
        <div className="flex flex-wrap gap-4 font-bold">
          <a href={githubUrl}>GitHub</a>
          <a href={privacyPolicyUrl}>隐私政策</a>
          <a href={sourceLicenseUrl}>许可证</a>
        </div>
        <p>
          CopyUp 基于开源项目 Clipy 开发，遵循 MIT 许可证。剪贴板内容留在本地。
        </p>
      </footer>
    </div>
  )
}

export default App
