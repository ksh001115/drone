
import gym

import numpy as np

from dronesim import DroneSim

# DEFAULT_ACTION_SIZE = 15
DEFAULT_ACTION_SIZE = 45
DEFAULT_GOAL_RADIUS = 1
DEFAULT_TIME_STEP = 0.05
DEFAULT_LINEAR_VELOCITY = 1
#NUM_SEGMENTS = 5
NUM_SEGMENTS = 15
MAX_ANGULAR_VELOCITY = np.pi / 2
#MAX_FLIGHT_HEIGHT = 3
MAX_FLIGHT_HEIGHT = 2
MIN_FLIGHT_HEIGHT = 0.2

def get_init_args(env_config):
    """get DroneSim init arguments from env_config"""

    dict_worlds = None
    master_uri = None
    heading = False

    if 'dict_worlds' in env_config.keys():
        dict_worlds = env_config['dict_worlds']

    if 'list_master_uri' in env_config.keys():
        if env_config['list_master_uri'] is not None:
            index = env_config.worker_index % env_config['num_workers']
            master_uri = env_config['list_master_uri'][index]

    if 'use_random_heading' in env_config.keys():
        heading = env_config['use_random_heading']

    return dict_worlds, master_uri, heading

class DroneSimEnv(gym.Env):
    """OpenAI Gym Environment Class for ROS-Gazebo Simulation"""
    def __init__(self, env_config):
        self.worker_index = env_config.worker_index
        print("[WORKER {}] Initializing DroneSimEnv...".format(self.worker_index))
        if 'result_csv' in env_config.keys():
            self.result_csv = env_config['result_csv']
        dict_worlds, master_uri, heading = get_init_args(env_config)

        self.sim = DroneSim(dict_worlds=dict_worlds,
                            master_uri=master_uri,
                            random_heading=heading)
        self.sim.sleep_sim_time(5)
        num_features = self.sim.get_drone_state().size
        print("[WORKER {}] Feature size for this environment is {}". \
                format(self.worker_index, num_features))
        if self.worker_index < 1:
            self.sim.shutdown()

        self.time = 0
        self.prev_distance = None
        self.step_count = 0
        self.vel_check = 0

        self.action_size = DEFAULT_ACTION_SIZE
        self.action_space = gym.spaces.Discrete(self.action_size)
        limit = np.array([np.finfo(np.float32).max] * num_features)
        self.observation_space = gym.spaces.Box(-limit, limit, dtype=np.float32)

    def __del__(self):
        self.sim.shutdown()

    def step(self, action):
        """step operation"""
        if self.step_count == 0:
            self.sim.reset()
            self.prev_distance = None
        self.step_count += 1

        self._send_action(action)
        self._sleep_interval(DEFAULT_TIME_STEP)
        self._print_state(False)

        done, goal_reached = self._check_state()
        reward = self._compute_reward(done, action, goal_reached)

        observation = self.sim.get_drone_state()
        info = {}

        return observation, reward, done, info

    def reset(self):
        """reset environment"""
        self.step_count = 0
        self.vel_check = 0
        observation = self.sim.get_drone_state()

        return observation

    def _sleep_interval(self, interval):
        """sleep until next simulation time interval"""
        while self.sim.get_sim_time() != 0:
            if (self.sim.get_sim_time() - self.time) < interval:
                self.sim.sleep_sim_time(0.0001)
            else:
                break
        self.time = self.sim.get_sim_time()

    def _send_action(self, action):
        """send command input based on action. send stop command when done"""
        #yaw_rate = ((NUM_SEGMENTS-1)/2 - (action%NUM_SEGMENTS)) * MAX_ANGULAR_VELOCITY/2
        yaw_rate = ((NUM_SEGMENTS-11)/2 - (action%(NUM_SEGMENTS-10))) * MAX_ANGULAR_VELOCITY/2
        #vel_lin = [(action//NUM_SEGMENTS), 0, 0]
        vel_lin = [(action//NUM_SEGMENTS), 0, (action//(NUM_SEGMENTS-10))%(NUM_SEGMENTS-12)-1]
        vel_ang = [0, 0, yaw_rate]
        self.sim.send_command(linear=vel_lin, angular=vel_ang)

    def _check_state(self):
        """check if the drone has reached the goal or if it has collided with an object"""
        done = False
        goal_reached = False

        if self.sim.drone.distance_to_goal < DEFAULT_GOAL_RADIUS:
            done = True
            goal_reached = True
        elif self.sim.drone.is_contact:
            done = True
        elif self.sim.drone.pose.position.z > MAX_FLIGHT_HEIGHT:
            done = True
        elif self.sim.drone.pose.position.z < MIN_FLIGHT_HEIGHT:
            done = True

        if done:
            self.sim.send_command()

        return done, goal_reached

    def _compute_reward(self, done, action, goal_reached):
        """
        higher rewards when the drone approach or arrive at the goal.
        penalty if the drone hits an object
        """
        rate = 20
        penalty_over_time = -1
        vel_linX = action//NUM_SEGMENTS
        penalty_to_vel = 0

        if self.prev_distance is None:
            self.prev_distance = self.sim.drone.distance_to_goal

        if done:
            if goal_reached:
                print("[WORKER {}] Goal!!".format(self.worker_index))
                reward = 2000 + self.sim.distance_base * 10
                ## data write
                with open(self.result_csv, 'a') as file_:
                    file_.write('1,')
            else:
                print("[WORKER {}] Collision!!".format(self.worker_index))
		## reward = -1000          
                reward = -1500
                ## data write
                with open(self.result_csv, 'a') as file_:
                    file_.write('0,')
        else:
            progress = (self.prev_distance-self.sim.drone.distance_to_goal) * rate

            if vel_linX == 0:
                self.vel_check = self.vel_check + 1
                if self.vel_check > 10:
                    penalty_to_vel = -3
            else:
                self.vel_check = 0

            reward = progress + penalty_over_time + penalty_to_vel

        self.prev_distance = self.sim.drone.distance_to_goal

        return reward

    def _print_state(self, enable):
        """print current drone state"""
        if enable:
            print("========================================")
            print("DEPTH IMAGE")
            print(self.sim.drone.depth_image)
            print("DRONE POSITION")
            print("X: {}\nY: {}\nZ: {}\n".format(self.sim.drone.pose.position.x,
                                                 self.sim.drone.pose.position.y,
                                                 self.sim.drone.pose.position.z))
            print("DISTANCE TO GOAL")
            print(self.sim.drone.distance_to_goal)
            print("ANGLE TO GOAL")
            print(self.sim.drone.angle_to_goal)
