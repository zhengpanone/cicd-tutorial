# 使用官方 Node.js 镜像
FROM node:18-alpine

# 设置工作目录
WORKDIR /app

# 复制 package.json 并安装依赖
COPY package.json .
RUN npm install --production

# 复制应用代码
COPY app.js .

# 暴露端口
EXPOSE 3000

# 启动应用
CMD ["npm", "start"]
