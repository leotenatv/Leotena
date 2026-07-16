-- CreateEnum
CREATE TYPE "ChannelDrm" AS ENUM ('NONE', 'WIDEVINE', 'CLEARKEY');

-- CreateEnum
CREATE TYPE "DevicePlan" AS ENUM ('FREE', 'PREMIUM');

-- CreateTable
CREATE TABLE "AdminUser" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "passwordHash" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AdminUser_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Setting" (
    "id" TEXT NOT NULL DEFAULT 'singleton',
    "supportWhatsApp" TEXT NOT NULL DEFAULT '255712345678',
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Setting_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Channel" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "category" TEXT NOT NULL,
    "url" TEXT NOT NULL DEFAULT '',
    "drm" "ChannelDrm" NOT NULL DEFAULT 'NONE',
    "clearKey" TEXT NOT NULL DEFAULT '',
    "premium" BOOLEAN NOT NULL DEFAULT true,
    "viewers" INTEGER NOT NULL DEFAULT 0,
    "live" BOOLEAN NOT NULL DEFAULT false,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "imageUrl" TEXT NOT NULL DEFAULT '',
    "gradientStart" TEXT NOT NULL DEFAULT '1D4A82',
    "gradientEnd" TEXT NOT NULL DEFAULT '2C6DB5',
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "genre" TEXT,
    "year" TEXT,
    "rating" TEXT,
    "duration" TEXT,
    "resolution" TEXT,
    "language" TEXT,
    "director" TEXT,
    "description" TEXT,
    "genres" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Channel_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ScheduleItem" (
    "id" TEXT NOT NULL,
    "dateTime" TIMESTAMP(3) NOT NULL,
    "title" TEXT NOT NULL,
    "subtitle" TEXT NOT NULL DEFAULT '',
    "channel" TEXT NOT NULL DEFAULT '',
    "team1" TEXT NOT NULL DEFAULT '',
    "team2" TEXT NOT NULL DEFAULT '',
    "icon" TEXT NOT NULL DEFAULT 'live_tv_rounded',
    "live" BOOLEAN NOT NULL DEFAULT false,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "gradientStart" TEXT NOT NULL DEFAULT '1D4A82',
    "gradientEnd" TEXT NOT NULL DEFAULT '2C6DB5',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ScheduleItem_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CarouselSlide" (
    "id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "imageUrl" TEXT NOT NULL DEFAULT '',
    "order" INTEGER NOT NULL DEFAULT 0,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "gradientStart" TEXT NOT NULL DEFAULT '0F2748',
    "gradientEnd" TEXT NOT NULL DEFAULT '19B26B',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CarouselSlide_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PricingPlan" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "price" TEXT NOT NULL,
    "days" INTEGER NOT NULL,
    "note" TEXT NOT NULL DEFAULT '',
    "popular" BOOLEAN NOT NULL DEFAULT false,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PricingPlan_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Device" (
    "id" TEXT NOT NULL,
    "deviceId" TEXT NOT NULL,
    "name" TEXT NOT NULL DEFAULT '',
    "phone" TEXT NOT NULL DEFAULT '',
    "plan" "DevicePlan" NOT NULL DEFAULT 'FREE',
    "active" BOOLEAN NOT NULL DEFAULT true,
    "premiumUntil" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Device_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SubscriptionRecord" (
    "id" TEXT NOT NULL,
    "deviceRecordId" TEXT NOT NULL,
    "userName" TEXT NOT NULL,
    "packageName" TEXT NOT NULL,
    "amount" TEXT NOT NULL,
    "success" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SubscriptionRecord_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "AdminUser_email_key" ON "AdminUser"("email");

-- CreateIndex
CREATE INDEX "Channel_category_idx" ON "Channel"("category");

-- CreateIndex
CREATE INDEX "ScheduleItem_dateTime_idx" ON "ScheduleItem"("dateTime");

-- CreateIndex
CREATE UNIQUE INDEX "Device_deviceId_key" ON "Device"("deviceId");

-- AddForeignKey
ALTER TABLE "SubscriptionRecord" ADD CONSTRAINT "SubscriptionRecord_deviceRecordId_fkey" FOREIGN KEY ("deviceRecordId") REFERENCES "Device"("id") ON DELETE CASCADE ON UPDATE CASCADE;
