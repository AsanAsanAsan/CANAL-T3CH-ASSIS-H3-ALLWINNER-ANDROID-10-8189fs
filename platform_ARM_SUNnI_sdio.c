/******************************************************************************
 *
 * Copyright(c) 2013 - 2017 Realtek Corporation.
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of version 2 of the GNU General Public License as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
 * more details.
 *
 *****************************************************************************/
/*
 * Description:
 *      This file can be applied to following platforms:
 *      CONFIG_PLATFORM_ARM_SUN6I
 *      CONFIG_PLATFORM_ARM_SUN7I
 *      CONFIG_PLATFORM_ARM_SUN8I
 */
#include <drv_types.h>
#ifdef CONFIG_GPIO_WAKEUP
#include <linux/gpio.h>
#endif

#ifdef CONFIG_MMC
static int sdc_id = -1;

/* Allwinner 4.9 BSP: 由 sunxi-wlan / sunxi-mmc 匯出（裝置樹提供腳位） */
extern void sunxi_wlan_set_power(int on);
extern int  sunxi_wlan_get_bus_index(void);
extern int  sunxi_wlan_get_oob_irq(void);
extern void sunxi_mmc_rescan_card(unsigned id);

#ifdef CONFIG_GPIO_WAKEUP
extern unsigned int oob_irq;
#endif
#endif /* CONFIG_MMC */

/*
 * Return:
 *      0:      power on successfully
 *      others: power on failed
 */
int platform_wifi_power_on(void)
{
        int ret = 0;

#ifdef CONFIG_MMC
        {
                int bus = sunxi_wlan_get_bus_index();

                if (bus < 0) {
                        RTW_INFO("%s: sunxi_wlan_get_bus_index failed (%d)\n", __FUNCTION__, bus);
                        ret = -1;
                } else {
                        sdc_id = bus;
                        RTW_INFO("----- %s sdc_id: %d\n", __FUNCTION__, sdc_id);

                        sunxi_wlan_set_power(1);
                        mdelay(100);
                        sunxi_mmc_rescan_card(sdc_id);

                        RTW_INFO("%s: power up, rescan card.\n", __FUNCTION__);
                }

#ifdef CONFIG_GPIO_WAKEUP
                {
                        int irq = sunxi_wlan_get_oob_irq();

                        if (irq <= 0) {
                                RTW_INFO("No definition of wake up host PIN\n");
                                ret = -1;
                        } else
                                oob_irq = irq;
                }
#endif /* CONFIG_GPIO_WAKEUP */
        }
#endif /* CONFIG_MMC */

        return ret;
}

void platform_wifi_power_off(void)
{
#ifdef CONFIG_MMC
        sunxi_wlan_set_power(0);
        mdelay(100);
        if (sdc_id >= 0)
                sunxi_mmc_rescan_card(sdc_id);

        RTW_INFO("%s: remove card, power off.\n", __FUNCTION__);
#endif /* CONFIG_MMC */
}

