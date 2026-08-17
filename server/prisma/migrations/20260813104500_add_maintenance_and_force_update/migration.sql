-- AlterTable
ALTER TABLE "Setting" ADD COLUMN "maintenanceMode" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "Setting" ADD COLUMN "maintenanceMessage" TEXT NOT NULL DEFAULT '';
ALTER TABLE "Setting" ADD COLUMN "forceUpdateEnabled" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "Setting" ADD COLUMN "minCodeVersion" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "Setting" ADD COLUMN "minAppVersion" TEXT NOT NULL DEFAULT '';
ALTER TABLE "Setting" ADD COLUMN "forceUpdateMessage" TEXT NOT NULL DEFAULT '';
ALTER TABLE "Setting" ADD COLUMN "playStoreUrl" TEXT NOT NULL DEFAULT 'https://play.google.com/store/apps/details?id=com.ghettodevelopers.leotena';
