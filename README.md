# Create Custom ISO with bootc

This guide explains how to build the installer image (Anaconda) and generate the LiveISO from a custom `bootc` image using `just`.

### 1. Build the Anaconda Image with Your Custom bootc Image

To build the installer container image using your custom `bootc` image, run:

```
sudo just build <your-custom-bootc-image>
```

> **Example:**
>
> ```
> sudo just build quay.io/centos-bootc/centos-bootc:stream9
> ```

### 2. Create the LiveISO with Anaconda

After building the image, generate the installation ISO file with the command:

```
sudo just create-iso
```

> 💡 **Note:** The final ISO will be saved inside a new directory (`bootc-generic-iso/` or corresponding) automatically created in the folder where you executed the `just` command.