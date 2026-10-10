import { Version } from "./Config.js";
import { Installed, IsCheckout, LatestCommit } from "./PluginInstaller.js";

export async function ReportVersion() {
  const Here = Installed();

  console.log(`Claudio ${Version}`);

  if (IsCheckout()) {
    console.log("Running from a git checkout, so it does not update itself. Pull and rebuild to change it.");
    return;
  }

  console.log(Here ? `Installed commit ${Here.commit.slice(0, 7)} on ${new Date(Here.at).toLocaleString()}` : "No installed commit is recorded, so the next update check installs the newest one.");

  try {
    const Newest = await LatestCommit();

    console.log(Here && Here.commit === Newest.sha
      ? "Up to date with main."
      : `Main is at ${Newest.sha.slice(0, 7)} (${Newest.commit.message.split("\n")[0]}). The bridge installs it by itself within a few hours, or straight away when it next starts.`);
  } catch (Error) {
    console.log(`Could not check main: ${(Error as Error).message}`);
  }
}
